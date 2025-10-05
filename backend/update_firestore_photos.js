// Save as update_firestore_photos.js
const firebaseAdmin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

firebaseAdmin.initializeApp({
  credential: firebaseAdmin.credential.cert(serviceAccount),
});

const db = firebaseAdmin.firestore();

async function updatePhotos() {
  try {
    const docRef = db.collection('chat').doc('f50fd98e-e51b-4145-bcdb-4451ca661d59');
    await docRef.update({
      photos: [{
        uri: 'https://storage.googleapis.com/squadsync-media/chat_media/000d8f3d-d4c7-47f0-85a7-5153567486e1.jpg',
        creation_timestamp: 1744174635
      }],
      content: '', // Ensure content is set
      text: '' // Ensure text is set
    });
    console.log('Updated photos for document f50fd98e-e51b-4145-bcdb-4451ca661d59');
  } catch (error) {
    console.error('Error updating photos:', error);
  }
}

updatePhotos();