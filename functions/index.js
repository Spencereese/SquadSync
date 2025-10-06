const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Scheduled function to update timers every minute
exports.updateTimers = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const squadRef = db.collection('squad').doc('state');

    try {
      const doc = await squadRef.get();
      if (!doc.exists) {
        console.log('No squad state document found');
        return null;
      }

      const data = doc.data();
      let needsUpdate = false;
      const updates = {};

      // Update spot timers
      if (data.gameSpotTimers) {
        const updatedSpotTimers = {};
        for (const [game, timers] of Object.entries(data.gameSpotTimers)) {
          const updatedTimers = timers.map(timer => {
            if (timer && timer.startTime && timer.duration) {
              const elapsed = Math.floor((Date.now() - timer.startTime) / 1000);
              const remaining = timer.duration - elapsed;

              if (remaining <= 0) {
                // Timer expired - spot should be freed
                needsUpdate = true;
                return null; // Remove expired timer
              }
            }
            return timer;
          }).filter(timer => timer !== null); // Remove null timers

          if (updatedTimers.length > 0) {
            updatedSpotTimers[game] = updatedTimers;
          }
        }

        if (Object.keys(updatedSpotTimers).length !== Object.keys(data.gameSpotTimers).length) {
          updates.gameSpotTimers = updatedSpotTimers;
        }
      }

      // Update peacock timers
      if (data.peacockTimers) {
        const updatedPeacockTimers = {};
        for (const [player, timer] of Object.entries(data.peacockTimers)) {
          if (timer && timer.startTime && timer.duration) {
            const elapsed = Math.floor((Date.now() - timer.startTime) / 1000);
            const remaining = timer.duration - elapsed;

            if (remaining <= 0) {
              // Timer expired - remove from peacock queue
              needsUpdate = true;
              // Don't include expired timer in updates
            } else {
              updatedPeacockTimers[player] = timer;
            }
          }
        }

        if (Object.keys(updatedPeacockTimers).length !== Object.keys(data.peacockTimers).length) {
          updates.peacockTimers = updatedPeacockTimers;
        }
      }

      // Update Firestore if there were changes
      if (needsUpdate && Object.keys(updates).length > 0) {
        await squadRef.update(updates);
        console.log('Updated expired timers:', updates);
      } else {
        console.log('No timer updates needed');
      }

      return null;
    } catch (error) {
      console.error('Error updating timers:', error);
      return null;
    }
  });