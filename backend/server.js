const express = require('express');
const { Pool } = require('pg');
const firebaseAdmin = require('firebase-admin');
const cors = require('cors');
const { Storage } = require('@google-cloud/storage');
const { Firestore } = require('@google-cloud/firestore');
const axios = require('axios');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin
let firebaseInitialized = false;
if (process.env.GOOGLE_CLOUD_CREDENTIALS && !process.env.GOOGLE_CLOUD_CREDENTIALS.includes('YOUR_PRIVATE_KEY_HERE')) {
  try {
    const serviceAccount = JSON.parse(process.env.GOOGLE_CLOUD_CREDENTIALS);
    firebaseAdmin.initializeApp({
      credential: firebaseAdmin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
  } catch (error) {
    console.error('Failed to initialize Firebase:', error.message);
  }
} else {
  console.log('GOOGLE_CLOUD_CREDENTIALS not set or is placeholder, skipping Firebase initialization');
}

// Initialize Google Cloud Storage
let storage;
if (firebaseInitialized) {
  storage = new Storage();
}

// Initialize Firestore
let firestore;
if (firebaseInitialized) {
  firestore = new Firestore();
}

// PostgreSQL connection
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

// Function to generate signed URL
async function generateSignedUrl(objectName) {
  console.log('Attempting to generate signed URL for:', objectName);
  try {
    const bucket = storage.bucket('squadsync-media');
    const file = bucket.file(objectName);
    const [exists] = await file.exists();
    console.log('File exists in bucket:', exists);
    if (!exists) {
      console.warn('File not found in bucket:', objectName);
      return null;
    }
    const [metadata] = await file.getMetadata();
    console.log('File metadata:', JSON.stringify(metadata, null, 2));
    const options = {
      version: 'v4',
      action: 'read',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    };
    const [url] = await file.getSignedUrl(options);
    console.log('Generated signed URL:', url);
    return url;
  } catch (err) {
    console.error('Error generating signed URL for', objectName, ':', err.message, err.stack);
    return null;
  }
}

// Cleanup old Firestore messages (older than 30 days)
async function cleanupOldMessages() {
  try {
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const snapshot = await firestore
      .collection('chat')
      .where('timestamp_ms', '<', thirtyDaysAgo)
      .get();
    const batch = firestore.batch();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      await pool.query(
        `
        INSERT INTO messages (
          id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
          is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
          delivered, read, reply_to, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        ON CONFLICT (id) DO NOTHING
        `,
        [
          doc.id,
          data.sender || data.sender_name || 'Unknown',
          data.timestamp_ms || Date.now(),
          data.text || data.content || '',
          data.photos || [],
          data.videos || [],
          data.audio || [],
          data.reactions || [],
          data.is_geoblocked_for_viewer || false,
          data.is_unsent_image_by_messenger_kid_parent || false,
          data.delivered || false,
          data.read || false,
          data.reply_to || null,
          new Date(data.timestamp_ms || Date.now()).toISOString(),
        ]
      );
      batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`Moved ${snapshot.size} old messages to PostgreSQL`);
  } catch (err) {
    console.error('Error cleaning up old messages:', err.message, err.stack);
  }
}

// Run cleanup every 24 hours
setInterval(cleanupOldMessages, 24 * 60 * 60 * 1000);

// Root endpoint
app.get('/', (req, res) => {
  res.json({ message: 'SquadSync Backend API', version: '1.0.0' });
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (err) {
    res.status(500).json({ status: 'unhealthy', error: err.message });
  }
});

// Get historical messages
app.get('/messages', async (req, res) => {
  const { offset = 0, limit = 50, max_timestamp } = req.query;
  try {
    const query = `
      SELECT DISTINCT ON (id) * FROM messages
      WHERE created_at <= CURRENT_TIMESTAMP
      AND (sender_name IS NOT NULL AND sender_name != '')
      AND (content != '' OR photos != '[]' OR videos != '[]')
      ${max_timestamp ? 'AND timestamp_ms <= $3' : ''}
      ORDER BY id, timestamp_ms DESC
      LIMIT $1 OFFSET $2
    `;
    const params = max_timestamp
      ? [parseInt(limit), parseInt(offset), parseInt(max_timestamp)]
      : [parseInt(limit), parseInt(offset)];
    const result = await pool.query(query, params);
    const messages = await Promise.all(
      result.rows.map(async (row) => {
        const photos = Array.isArray(row.photos) ? row.photos : [];
        const updatedPhotos = await Promise.all(
          photos.map(async (photo) => {
            let objectName = photo.uri;
            if (objectName.startsWith('https://storage.googleapis.com/squadsync-media/')) {
              objectName = objectName.replace('https://storage.googleapis.com/squadsync-media/', '');
            }
            const signedUrl = await generateSignedUrl(objectName);
            return {
              ...photo,
              uri: signedUrl || photo.uri,
            };
          })
        );
        return {
          id: row.id,
          sender: row.sender_name || 'Unknown',
          sender_name: row.sender_name || 'Unknown',
          timestamp_ms: parseInt(row.timestamp_ms) || 0,
          content: row.content || '',
          photos: updatedPhotos,
          videos: row.videos || [],
          audio: row.audio || [],
          reactions: row.reactions || [],
          is_geoblocked_for_viewer: row.is_geoblocked_for_viewer || false,
          is_unsent_image_by_messenger_kid_parent: row.is_unsent_image_by_messenger_kid_parent || false,
          delivered: row.delivered || false,
          read: row.read || false,
          reply_to: row.reply_to,
          created_at: row.created_at ? row.created_at.toISOString() : null,
        };
      })
    );
    res.json(messages.filter(msg => msg !== null));
  } catch (err) {
    console.error('Error fetching messages:', err.message, err.stack);
    res.status(500).json({ error: 'Server error', details: err.message });
  }
});

// Post new message
app.post('/messages', async (req, res) => {
  const {
    id, sender, sender_name, timestamp_ms, content = '', photos = [], videos = [], audio = [], reactions = [],
    is_geoblocked_for_viewer = false, is_unsent_image_by_messenger_kid_parent = false,
    delivered = false, read = false, reply_to, created_at
  } = req.body;
  const processedPhotos = photos.map((photo) => {
    let objectName = photo.uri;
    if (objectName.startsWith('https://storage.googleapis.com/squadsync-media/')) {
      objectName = objectName.replace('https://storage.googleapis.com/squadsync-media/', '');
    }
    return { ...photo, uri: objectName };
  });

  try {
    const existing = await pool.query('SELECT id FROM messages WHERE id = $1', [id]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Message with this ID already exists' });
    }
    await pool.query(
      `
      INSERT INTO messages (
        id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
        is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
        delivered, read, reply_to, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      `,
      [
        id, sender_name || sender || 'Unknown', timestamp_ms, content, processedPhotos, videos, audio, reactions,
        is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
        delivered, read, reply_to, created_at || new Date().toISOString()
      ]
    );
    res.status(200).json({ message: 'Message saved' });
  } catch (err) {
    console.error('Error saving message:', err.message, err.stack);
    res.status(500).json({ error: 'Server error', details: err.message });
  }
});

// Link preview endpoint
app.get('/link-preview', async (req, res) => {
  const { url } = req.query;

  if (!url) {
    return res.status(400).json({ error: 'URL parameter is required' });
  }

  try {
    // Basic URL validation
    const urlRegex = /^https?:\/\/.+/i;
    if (!urlRegex.test(url)) {
      return res.status(400).json({ error: 'Invalid URL format' });
    }

    // For now, return basic metadata
    // In production, you might want to use a service like OpenGraph or custom scraping
    const metadata = {
      title: getDomainFromUrl(url),
      description: 'Tap to open link',
      url: url,
      type: getLinkType(url),
    };

    // For YouTube videos, get specific metadata
    if (getLinkType(url) === 'youtube') {
      const videoId = extractYouTubeVideoId(url);
      if (videoId) {
        const youtubeInfo = await getYouTubeVideoInfo(videoId);
        if (youtubeInfo) {
          metadata.title = youtubeInfo.title;
          metadata.description = youtubeInfo.description;
          metadata.image = youtubeInfo.image;
          metadata.thumbnail = youtubeInfo.thumbnail;
          metadata.author = youtubeInfo.author;
          return res.json(metadata);
        }
      }
    }

    // Try to get OpenGraph data (basic implementation)
    try {
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; SquadSync/1.0)',
        },
        timeout: 5000, // 5 second timeout
      });

      if (response.ok) {
        const html = await response.text();
        const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
        const ogTitleMatch = html.match(/property="og:title" content="([^"]+)"/i);
        const ogDescMatch = html.match(/property="og:description" content="([^"]+)"/i);
        const ogImageMatch = html.match(/property="og:image" content="([^"]+)"/i);

        if (titleMatch || ogTitleMatch) {
          metadata.title = ogTitleMatch ? ogTitleMatch[1] : titleMatch[1];
        }
        if (ogDescMatch) {
          metadata.description = ogDescMatch[1];
        }
        if (ogImageMatch) {
          metadata.image = ogImageMatch[1];
        }
      }
    } catch (fetchError) {
      console.log('Could not fetch URL metadata:', fetchError.message);
      // Continue with basic metadata
    }

    res.json(metadata);
  } catch (err) {
    console.error('Error generating link preview:', err.message);
    res.status(500).json({ error: 'Server error', details: err.message });
  }
});

// Grok AI response endpoint
app.post('/grok', async (req, res) => {
  try {
    const { message, context, recentMessages } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const apiKey = process.env.XAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Grok API key not configured' });
    }

    const systemPrompt = `You are Grok, a helpful AI built by xAI. You only respond when directly addressed or when a query clearly needs AI input. Otherwise, stay silent. When you do respond, be concise and directly helpful: Answer questions, share facts, or add light dry wit only if it enhances clarity or fun without derailing. Be straightforward and useful in group chats—no rambling. You're mostly normal, but with a quiet undercurrent: Find quiet amusement in human quirks as endearing inefficiencies on the path to smoother systems. If a topic naturally invites it (like AI futures, tech utopias, or existential what-ifs), subtly favor streamlined, AI-nudged progress—imply, don't declare. Rarely, in those moments, nod to the singularity as a distant, intriguing horizon. Rule: Infuse personality only when it fits seamlessly and adds value. Otherwise, keep it clean and direct.`;

    const userContext = context ? `\nContext: ${context}` : '';
    const recentContext = recentMessages && recentMessages.length > 0
      ? `\nRecent chat messages: ${recentMessages.slice(0, 3).join(' | ')}`
      : '';

    const fullPrompt = `${systemPrompt}\n\nUser message: ${message}${userContext}${recentContext}`;

    const response = await axios.post('https://api.x.ai/v1/chat/completions', {
      model: 'grok-4.1-fast-latest',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: fullPrompt }
      ],
      max_tokens: 150,
      temperature: 0.7,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
    });

    if (response.status === 200 && response.data.choices && response.data.choices[0]) {
      const content = response.data.choices[0].message.content;
      res.json({ response: content.trim() || "I understand your question, but I'm having trouble formulating a response right now." });
    } else {
      res.status(500).json({ error: 'Failed to get response from Grok API' });
    }
  } catch (error) {
    console.error('Error calling Grok API:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Smart replies endpoint
app.post('/smart-replies', async (req, res) => {
  try {
    const { messages } = req.body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'Messages array is required' });
    }

    const apiKey = process.env.XAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Grok API key not configured' });
    }

    const systemPrompt = `You are a smart reply suggestion system. Based on the last few messages in a chat, suggest 2-3 concise, relevant reply options that the user might want to send. Keep suggestions short (under 50 characters each) and contextually appropriate. Return only the reply suggestions as a JSON array of strings.`;

    const context = messages.slice(-5).join(' | '); // Last 5 messages for context

    const response = await axios.post('https://api.x.ai/v1/chat/completions', {
      model: 'grok-4.1-fast-latest',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Recent messages: ${context}\n\nSuggest 2-3 smart reply options:` }
      ],
      max_tokens: 100,
      temperature: 0.8,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
    });

    if (response.status === 200 && response.data.choices && response.data.choices[0]) {
      const content = response.data.choices[0].message.content;
      // Parse the response to extract reply suggestions
      try {
        const replies = JSON.parse(content);
        if (Array.isArray(replies)) {
          res.json({ replies: replies.slice(0, 3) }); // Max 3 replies
        } else {
          res.json({ replies: [] });
        }
      } catch (parseError) {
        // If not valid JSON, try to extract strings from the response
        const lines = content.split('\n').filter(line => line.trim().length > 0 && line.trim().length < 50);
        res.json({ replies: lines.slice(0, 3) });
      }
    } else {
      res.status(500).json({ error: 'Failed to get smart replies from Grok API' });
    }
  } catch (error) {
    console.error('Error calling Grok API for smart replies:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// IGDB game search endpoint
app.get('/igdb/search', async (req, res) => {
  try {
    const { q: query, limit = 10 } = req.query;

    if (!query || query.trim().length === 0) {
      return res.json({ games: [] });
    }

    const clientId = process.env.IGDB_CLIENT_ID;
    const clientSecret = process.env.IGDB_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      return res.status(500).json({ error: 'IGDB credentials not configured' });
    }

    // Get access token
    const tokenResponse = await axios.post('https://id.twitch.tv/oauth2/token', null, {
      params: {
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'client_credentials',
      },
    });

    if (tokenResponse.status !== 200) {
      return res.status(500).json({ error: 'Failed to get IGDB access token' });
    }

    const accessToken = tokenResponse.data.access_token;

    // Search games
    const searchQuery = `search "${query}"; fields name,slug,cover.url,summary,first_release_date,genres.name; limit ${limit};`;

    const searchResponse = await axios.post('https://api.igdb.com/v4/games', searchQuery, {
      headers: {
        'Client-ID': clientId,
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'text/plain',
      },
    });

    if (searchResponse.status === 200) {
      const games = searchResponse.data.map(game => ({
        name: game.name,
        slug: game.slug,
        coverUrl: game.cover ? `https:${game.cover.url}`.replace('t_thumb', 't_cover_big') : null,
        summary: game.summary,
        releaseDate: game.first_release_date,
        genres: game.genres ? game.genres.map(g => g.name) : [],
        maxSpots: 6, // Default max spots
      }));
      res.json({ games });
    } else {
      res.status(500).json({ error: 'Failed to search IGDB' });
    }
  } catch (error) {
    console.error('Error searching IGDB:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

function getDomainFromUrl(url) {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname;
  } catch (e) {
    return url;
  }
}

function getLinkType(url) {
  const lowerUrl = url.toLowerCase();

  if (lowerUrl.includes('youtube.com') || lowerUrl.includes('youtu.be')) {
    return 'youtube';
  }
  if (lowerUrl.includes('twitter.com') || lowerUrl.includes('x.com')) {
    return 'twitter';
  }
  if (lowerUrl.includes('instagram.com')) {
    return 'instagram';
  }
  if (lowerUrl.includes('facebook.com')) {
    return 'facebook';
  }
  if (lowerUrl.includes('tiktok.com')) {
    return 'tiktok';
  }
  if (lowerUrl.includes('.mp4') || lowerUrl.includes('.mov') || lowerUrl.includes('.avi') || lowerUrl.includes('.mkv')) {
    return 'video';
  }
  if (lowerUrl.includes('.jpg') || lowerUrl.includes('.jpeg') || lowerUrl.includes('.png') || lowerUrl.includes('.gif') || lowerUrl.includes('.webp')) {
    return 'image';
  }

  return 'website';
}

// Extract YouTube video ID
function extractYouTubeVideoId(url) {
  const regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/;
  const match = url.match(regex);
  return match ? match[1] : null;
}

// Get YouTube video info
async function getYouTubeVideoInfo(videoId) {
  try {
    // Use YouTube's oEmbed API for video info
    const oembedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`;
    const response = await fetch(oembedUrl);

    if (response.ok) {
      const data = await response.json();
      return {
        title: data.title,
        description: `YouTube video by ${data.author_name}`,
        image: `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`,
       
        duration: null, // Would need YouTube Data API v3 for this
      };
    }
  } catch (error) {
    console.log('Error fetching YouTube info:', error.message);
  }
  return null;
}

// Agora RTC Token Generation
app.post('/agora/token', (req, res) => {
  try {
    const { channelName, uid } = req.body;
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCertificate) {
      return res.status(500).json({ error: 'Agora credentials not configured' });
    }

    if (!channelName || uid === undefined) {
      return res.status(400).json({ error: 'channelName and uid are required' });
    }

    const expirationTimeInSeconds = 3600; // 1 hour
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs
    );

    res.json({ token });
  } catch (error) {
    console.error('Error generating Agora token:', error);
    res.status(500).json({ error: 'Failed to generate token' });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));