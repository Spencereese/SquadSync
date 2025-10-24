const admin = require('firebase-admin');
const axios = require('axios');

// IGDB API Configuration
const IGDB_CLIENT_ID = process.env.CLIENT_ID || 'your_client_id_here';
const IGDB_CLIENT_SECRET = process.env.CLIENT_SECRET || 'your_client_secret_here';

// Initialize Firebase Admin (optional - comment out if no credentials)
let db = null;
try {
  const serviceAccount = JSON.parse(process.env.GOOGLE_CLOUD_CREDENTIALS || '{}');
  if (serviceAccount.type) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    db = admin.firestore();
    console.log('Firebase initialized successfully');
  } else {
    console.log('No Firebase credentials - will only fetch games without saving');
  }
} catch (e) {
  console.log('Firebase not available - will only fetch games without saving:', e.message);
}

// Get IGDB access token
async function getAccessToken() {
  try {
    const response = await axios.post('https://id.twitch.tv/oauth2/token', null, {
      params: {
        client_id: IGDB_CLIENT_ID,
        client_secret: IGDB_CLIENT_SECRET,
        grant_type: 'client_credentials'
      }
    });
    return response.data.access_token;
  } catch (error) {
    console.error('Error getting access token:', error.response?.data || error.message);
    throw error;
  }
}

// Search IGDB for games
async function searchGames(accessToken, query, limit = 5) {
  try {
    const response = await axios.post('https://api.igdb.com/v4/games', 
      `search "${query}"; fields name,slug,cover.url; limit ${limit};`,
      {
        headers: {
          'Client-ID': IGDB_CLIENT_ID,
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'text/plain'
        }
      }
    );

    console.log(`API response for "${query}":`, JSON.stringify(response.data, null, 2));

    return response.data.map(game => ({
      name: game.name,
      slug: game.slug,
      coverUrl: game.cover ? `https://images.igdb.com/igdb/image/upload/t_cover_big/${game.cover.image_id}.jpg` : null,
      maxSpots: 4 // Default max spots
    }));
  } catch (error) {
    console.error(`Error searching for "${query}":`, error.response?.data || error.message);
    return [];
  }
}

// Main seeding function
async function seedGames() {
  try {
    console.log('Starting game seeding with IGDB...');

    // Get access token
    const accessToken = await getAccessToken();
    console.log('Got IGDB access token');

    const popularQueries = [
      'call of duty',
      'apex legends',
      'fortnite',
      'counter strike',
      'valorant',
      'overwatch',
      'league of legends',
      'dota 2',
      'world of warcraft',
      'minecraft',
      'grand theft auto',
      'fifa',
      'madden',
      'rocket league',
      'rainbow six siege',
      'destiny 2',
      'halo',
      'battlefield',
      'the finals',
      'escape from tarkov',
      'pubg',
      'among us',
      'roblox',
      'genshin impact',
      'cyberpunk 2077',
      'the last of us',
      'god of war',
      'spiderman',
      'assassin\'s creed',
      'far cry'
    ];

    const allGames = [];
    const totalGames = 60;
    let totalFetched = 0;

    console.log('Fetching games from IGDB...');

    // Fetch games for each query
    for (const query of popularQueries) {
      if (totalFetched >= totalGames) break;

      console.log(`Searching for: ${query}`);
      const results = await searchGames(accessToken, query, 5);

      for (const game of results) {
        if (totalFetched >= totalGames) break;
        if (!allGames.some(g => g.slug === game.slug)) {
          allGames.push(game);
          totalFetched++;
        }
      }

      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    console.log(`Fetched ${allGames.length} unique games.`);

    if (db) {
      // Save to Firestore
      const batch = db.batch();
      allGames.forEach(game => {
        const docRef = db.collection('games').doc(game.slug);
        batch.set(docRef, game, { merge: true });
      });

      await batch.commit();
      console.log(`✅ Successfully seeded ${allGames.length} games to Firestore!`);
    } else {
      console.log(`📋 Would seed ${allGames.length} games to Firestore (no credentials available)`);
    }

    console.log('Sample games:');
    allGames.slice(0, 5).forEach(game => {
      console.log(`  - ${game.name} (${game.slug})`);
    });

  } catch (error) {
    console.error('Error seeding games:', error);
  } finally {
    process.exit(0);
  }
}

// Run the seeding
seedGames();