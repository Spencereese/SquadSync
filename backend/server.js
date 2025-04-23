const express = require('express');
const { Pool } = require('pg');
const firebaseAdmin = require('firebase-admin');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin
const serviceAccount = require('./service-account.json');
firebaseAdmin.initializeApp({
  credential: firebaseAdmin.credential.cert(serviceAccount),
});

// PostgreSQL connection
const pool = new Pool({
  user: 'postgres',
  host: '34.133.101.232',
  database: 'squadsync',
  password: 'Lainlain0',
  port: 5432,
});

// Get historical messages
app.get('/messages', async (req, res) => {
  const { offset = 0, limit = 50 } = req.query;
  try {
    const result = await pool.query(
      'SELECT * FROM messages ORDER BY timestamp_ms DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Post new message
app.post('/messages', async (req, res) => {
  const {
    id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
    is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
    delivered, read, reply_to, created_at
  } = req.body;
  try {
    await pool.query(
      `
      INSERT INTO messages (
        id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
        is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
        delivered, read, reply_to, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      `,
      [
        id, sender_name, timestamp_ms, content, json.encode(photos), json.encode(videos),
        json.encode(audio), json.encode(reactions), is_geoblocked_for_viewer,
        is_unsent_image_by_messenger_kid_parent, delivered, read, reply_to, created_at
      ]
    );
    res.status(200).send('Message saved');
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));