const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Note: admin.initializeApp() is called in index.js

// Cloud function to handle smart lobby disbanding
// Triggered when a peacock document is updated
exports.disbandLobby = functions.firestore
  .document('peacocks/{peacockId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const peacockId = context.params.peacockId;

    // Check if lobby should be disbanded
    const shouldDisband = await checkDisbandConditions(after, peacockId);

    if (shouldDisband) {
      // Delete the peacock document
      await admin.firestore().collection('peacocks').doc(peacockId).delete();
      console.log(`Disbanded lobby ${peacockId}`);

      // Notify remaining viewers/players
      await notifyDisband(after);
    }
  });

// Cloud function to periodically clean up expired lobbies
exports.cleanupExpiredLobbies = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredLobbies = await admin.firestore()
      .collection('peacocks')
      .where('timer', '<', now)
      .get();

    const deletePromises = [];
    for (const doc of expiredLobbies.docs) {
      deletePromises.push(doc.ref.delete());
      console.log(`Cleaned up expired lobby ${doc.id}`);
    }

    await Promise.all(deletePromises);
    return null;
  });

async function checkDisbandConditions(peacockData, peacockId) {
  const filled = peacockData.filled || [];
  const viewers = peacockData.viewers || [];
  const spots = peacockData.spots || 4;
  const timer = peacockData.timer;
  const hostUid = peacockData.hostUid;

  // Condition 1: Host left and no one else filled spots
  if (!filled.includes(hostUid) && filled.length === 0) {
    return true;
  }

  // Condition 2: All spots filled and game started (timer expired)
  if (filled.length >= spots && timer && timer.toDate() < new Date()) {
    return true;
  }

  // Condition 3: No viewers and no activity for 5 minutes
  if (viewers.length === 0 && filled.length <= 1) {
    // Check if created more than 5 minutes ago
    const createdAt = peacockData.createdAt;
    if (createdAt) {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      if (createdAt.toDate() < fiveMinutesAgo) {
        return true;
      }
    }
  }

  return false;
}

async function notifyDisband(peacockData) {
  const filled = peacockData.filled || [];
  const viewers = peacockData.viewers || [];
  const gameName = peacockData.game?.name || 'Unknown Game';

  // Send notifications to all participants
  const allUids = [...new Set([...filled, ...viewers])];

  for (const uid of allUids) {
    // You could send push notifications here
    // For now, just log
    console.log(`Notifying user ${uid} about disbanded ${gameName} lobby`);
  }
}