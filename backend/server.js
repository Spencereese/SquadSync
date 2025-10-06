const express = require('express');
const { Pool } = require('pg');
const firebaseAdmin = require('firebase-admin');
const cors = require('cors');
const { Storage } = require('@google-cloud/storage');
const { Firestore } = require('@google-cloud/firestore');

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin
const serviceAccount = JSON.parse(process.env.GOOGLE_CLOUD_CREDENTIALS);
firebaseAdmin.initializeApp({
  credential: firebaseAdmin.credential.cert(serviceAccount),
});

// Initialize Google Cloud Storage
const storage = new Storage();

// Initialize Firestore
const firestore = new Firestore();

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
        thumbnail: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
        author: data.author_name,
        duration: null, // Would need YouTube Data API v3 for this
      };
    }
  } catch (error) {
    console.log('Error fetching YouTube info:', error.message);
  }
  return null;
}

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));