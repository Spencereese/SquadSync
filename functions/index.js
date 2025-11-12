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

// Import disband lobby functions
const disbandFunctions = require('./disband_lobby');

// Export disband functions
exports.disbandLobby = disbandFunctions.disbandLobby;
exports.cleanupExpiredLobbies = disbandFunctions.cleanupExpiredLobbies;

// Function to send persistent lobby notifications to friends when a new peacock lobby is created
exports.notifyFriendsOfLobby = functions.firestore
  .document('peacocks/{peacockId}')
  .onCreate(async (snap, context) => {
    const peacockData = snap.data();
    const peacockId = context.params.peacockId;
    
    try {
      const hostUid = peacockData.hostUid;
      const gameName = peacockData.game?.name || 'Unknown Game';
      const hostName = peacockData.hostName || 'Unknown Player';
      const maxSpots = peacockData.spots || 4;
      const filled = peacockData.filled || [];
      const currentPlayers = filled.length;

      // Skip if lobby is already full
      if (currentPlayers >= maxSpots) {
        console.log(`Lobby ${peacockId} is already full, skipping notifications`);
        return null;
      }

      // Get host's friends list
      const hostDoc = await admin.firestore().collection('users').doc(hostUid).get();
      if (!hostDoc.exists) {
        console.log(`Host user ${hostUid} not found`);
        return null;
      }

      const hostData = hostDoc.data();
      const friendsUids = hostData?.friends || [];
      
      if (friendsUids.length === 0) {
        console.log(`Host ${hostUid} has no friends, skipping notifications`);
        return null;
      }

      // Get friend display names for notification
      const friendNames = [];
      for (const friendUid of friendsUids.slice(0, 3)) { // Limit to first 3 friends for notification
        try {
          const friendDoc = await admin.firestore().collection('users').doc(friendUid).get();
          if (friendDoc.exists) {
            const friendData = friendDoc.data();
            const displayName = friendData?.displayName || 'Unknown';
            friendNames.push(displayName);
          }
        } catch (error) {
          console.error(`Error getting friend ${friendUid} data:`, error);
        }
      }

      // Send notifications to friends
      const notificationPromises = friendsUids.map(async (friendUid) => {
        try {
          // Get friend's FCM tokens
          const friendDoc = await admin.firestore().collection('users').doc(friendUid).get();
          if (!friendDoc.exists) return;

          const friendData = friendDoc.data();
          const fcmTokens = friendData?.fcmTokens || [];
          
          if (fcmTokens.length === 0) return;

          // Check if friend has lobby notifications enabled
          const notificationSettings = friendData?.notificationSettings || {};
          const lobbyNotificationsEnabled = notificationSettings.lobby_available !== false;

          if (!lobbyNotificationsEnabled) {
            console.log(`Friend ${friendUid} has lobby notifications disabled`);
            return;
          }

          // Create notification payload
          const notificationPayload = {
            title: `${hostName}'s ${gameName} Lobby`,
            body: `${currentPlayers}/${maxSpots} players • ${friendNames.join(', ')}`,
            sound: 'default',
            badge: '1',
          };

          const dataPayload = {
            type: 'lobby_join',
            lobbyId: peacockId,
            gameName: gameName,
            hostName: hostName,
            currentPlayers: currentPlayers.toString(),
            maxPlayers: maxSpots.toString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          };

          // Send to all of friend's devices
          const messagingPromises = fcmTokens.map(token => 
            admin.messaging().send({
              token: token,
              notification: notificationPayload,
              data: dataPayload,
              android: {
                priority: 'high',
                notification: {
                  channelId: 'gaming_lobby_channel',
                  priority: 'max',
                  defaultVibrateTimings: false,
                  defaultSound: false,
                  ongoing: true, // Makes notification persistent
                  autoCancel: false,
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                    alert: notificationPayload,
                    'content-available': 1,
                  },
                },
                headers: {
                  'apns-priority': '10',
                  'apns-push-type': 'alert',
                },
              },
            })
          );

          const results = await Promise.allSettled(messagingPromises);
          
          // Log results
          results.forEach((result, index) => {
            if (result.status === 'rejected') {
              console.error(`Failed to send notification to token ${fcmTokens[index]}:`, result.reason);
            } else {
              console.log(`Successfully sent lobby notification to friend ${friendUid}`);
            }
          });

        } catch (error) {
          console.error(`Error sending notification to friend ${friendUid}:`, error);
        }
      });

      await Promise.all(notificationPromises);
      console.log(`Completed sending lobby notifications for peacock ${peacockId}`);

      return null;
    } catch (error) {
      console.error('Error in notifyFriendsOfLobby function:', error);
      return null;
    }
  });

// Function to clean up persistent lobby notifications when lobbies are deleted or become full
exports.cleanupLobbyNotifications = functions.firestore
  .document('peacocks/{peacockId}')
  .onDelete(async (snap, context) => {
    const peacockId = context.params.peacockId;
    
    try {
      console.log(`Cleaning up notifications for deleted lobby ${peacockId}`);
      
      // For now, we can't selectively cancel notifications by lobby ID
      // since FCM doesn't support canceling by data payload
      // This would need to be handled client-side when the app detects
      // the lobby no longer exists
      
      return null;
    } catch (error) {
      console.error('Error in cleanupLobbyNotifications function:', error);
      return null;
    }
  });

// Function to notify when lobby becomes full (cancel ongoing notifications)
exports.notifyLobbyFull = functions.firestore
  .document('peacocks/{peacockId}')
  .onUpdate(async (change, context) => {
    const peacockId = context.params.peacockId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    try {
      const beforeFilled = beforeData?.filled?.length || 0;
      const afterFilled = afterData?.filled?.length || 0;
      const maxSpots = afterData?.spots || 4;
      
      // Check if lobby just became full
      if (beforeFilled < maxSpots && afterFilled >= maxSpots) {
        console.log(`Lobby ${peacockId} just became full, would cancel ongoing notifications`);
        
        // Similar to delete function, client-side cleanup would be needed
        // since we can't cancel specific notifications server-side
        
        return null;
      }
      
      return null;
    } catch (error) {
      console.error('Error in notifyLobbyFull function:', error);
      return null;
    }
  });