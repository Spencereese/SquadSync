const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./service-account.json');

initializeApp({
  credential: firebaseAdmin.credential.cert(serviceAccount),
});

const db = getFirestore();

async function deleteEmptyMessages() {
  try {
    const snapshot = await db.collection('chat').where('content', '==', '').get();
    if (snapshot.empty) {
      console.log('No empty messages found.');
      return;
    }
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${snapshot.size} empty messages.`);
  } catch (error) {
    console.error('Error deleting empty messages:', error);
  }
}

deleteEmptyMessages();