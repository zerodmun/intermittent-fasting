const { DateTime } = require("luxon");

/**
 * Calculates the four target notification events for a fasting schedule:
 * 1. fasting_start_reminder
 * 2. fasting_start
 * 3. fasting_end_reminder
 * 4. fasting_end
 * 
 * Correctly handles Asia/Jakarta timezone and overnight schedules where endTime < startTime.
 */
function calculateScheduleEvents({
  userId,
  scheduleId,
  version,
  startTime,
  endTime,
  reminderBeforeStart = 10,
  reminderBeforeEnd = 10,
  timezone = "Asia/Jakarta",
  notificationSettings = {},
  baseDateTime = null,
}) {
  const zone = timezone || "Asia/Jakarta";
  const nowInZone = baseDateTime
    ? DateTime.fromISO(baseDateTime, { zone })
    : DateTime.now().setZone(zone);

  const [startHour, startMin] = (startTime || "17:00").split(":").map(Number);
  const [endHour, endMin] = (endTime || "09:00").split(":").map(Number);

  let startDt = nowInZone.set({
    hour: startHour,
    minute: startMin,
    second: 0,
    millisecond: 0,
  });

  let endDt = nowInZone.set({
    hour: endHour,
    minute: endMin,
    second: 0,
    millisecond: 0,
  });

  // Handle overnight fast: if endTime is earlier than or equal to startTime, end occurs on the following day
  if (endHour < startHour || (endHour === startHour && endMin <= startMin)) {
    endDt = endDt.plus({ days: 1 });
  }

  const startReminderDt = startDt.minus({ minutes: reminderBeforeStart });
  const endReminderDt = endDt.minus({ minutes: reminderBeforeEnd });

  const events = [];

  if (notificationSettings.startReminder !== false) {
    events.push({
      userId,
      scheduleId,
      eventId: `${scheduleId}_v${version}_fasting_start_reminder`,
      eventType: "fasting_start_reminder",
      version,
      scheduledTime: startReminderDt.toISO(),
    });
  }

  if (notificationSettings.startNotification !== false) {
    events.push({
      userId,
      scheduleId,
      eventId: `${scheduleId}_v${version}_fasting_start`,
      eventType: "fasting_start",
      version,
      scheduledTime: startDt.toISO(),
    });
  }

  if (notificationSettings.endReminder !== false) {
    events.push({
      userId,
      scheduleId,
      eventId: `${scheduleId}_v${version}_fasting_end_reminder`,
      eventType: "fasting_end_reminder",
      version,
      scheduledTime: endReminderDt.toISO(),
    });
  }

  if (notificationSettings.endNotification !== false) {
    events.push({
      userId,
      scheduleId,
      eventId: `${scheduleId}_v${version}_fasting_end`,
      eventType: "fasting_end",
      version,
      scheduledTime: endDt.toISO(),
    });
  }

  return events;
}

/**
 * Validates a task payload before execution:
 * 1. Schedule doc exists
 * 2. Schedule doc enabled == true
 * 3. Schedule doc version == task.version
 * 4. Task eventId not already processed
 */
function validateTaskExecution(currentScheduleDoc, taskVersion, isAlreadyProcessed) {
  if (!currentScheduleDoc) {
    return { valid: false, reason: "Schedule document does not exist" };
  }

  if (currentScheduleDoc.enabled !== true) {
    return { valid: false, reason: "Schedule is disabled" };
  }

  if (currentScheduleDoc.version !== taskVersion) {
    return {
      valid: false,
      reason: `Stale task: task version (${taskVersion}) != Firestore current version (${currentScheduleDoc.version})`,
    };
  }

  if (isAlreadyProcessed) {
    return { valid: false, reason: "Duplicate task: eventId already processed" };
  }

  return { valid: true };
}

/**
 * Processes task validation, FCM device lookup, multicast dispatch,
 * invalid token handling, and idempotency recording.
 */
async function processScheduledFcmDispatch({
  db,
  messaging,
  userId,
  scheduleId,
  version,
  eventType,
  eventId,
  scheduledTime,
  serverTimestamp,
}) {
  const taskVersion = Number(version);

  // 1. Fetch current schedule from Firestore
  const scheduleRef = db.collection("users").doc(userId).collection("notificationSchedules").doc(scheduleId);
  const scheduleSnap = await scheduleRef.get();
  const currentSchedule = scheduleSnap.exists ? scheduleSnap.data() : null;

  // 2. Check Firestore idempotency record
  const eventRef = db.collection("users").doc(userId).collection("processedEvents").doc(eventId);
  const eventSnap = await eventRef.get();
  const isAlreadyProcessed = eventSnap.exists;

  // 3. Validate task execution
  const validation = validateTaskExecution(currentSchedule, taskVersion, isAlreadyProcessed);
  if (!validation.valid) {
    return { status: "ignored", reason: validation.reason };
  }

  // 4. Retrieve devices from users/{userId}/devices/{deviceId}
  const devicesSnap = await db.collection("users").doc(userId).collection("devices").get();
  if (devicesSnap.empty) {
    return { status: "no_devices", reason: "No devices found for user" };
  }

  const validDevices = [];
  const tokens = [];

  devicesSnap.forEach((doc) => {
    const data = doc.data() || {};
    if (
      data.enabled !== false &&
      data.fcmToken &&
      typeof data.fcmToken === "string" &&
      data.fcmToken.trim().length > 0
    ) {
      const trimmedToken = data.fcmToken.trim();
      if (!tokens.includes(trimmedToken)) {
        tokens.push(trimmedToken);
        validDevices.push({ docId: doc.id, token: trimmedToken });
      }
    }
  });

  if (tokens.length === 0) {
    return { status: "no_valid_tokens", reason: "No enabled device with non-empty FCM token found" };
  }

  // 5. Construct FCM Data Payload
  const messagePayload = {
    data: {
      type: "fasting_notification",
      eventId: String(eventId),
      eventType: String(eventType),
      scheduleId: String(scheduleId),
      version: String(taskVersion),
      scheduledTime: String(scheduledTime || ""),
      userId: String(userId),
    },
    tokens: tokens,
  };

  // 6. Perform Multicast FCM Dispatch
  let sendResult;
  try {
    sendResult = await messaging.sendEachForMulticast(messagePayload);
  } catch (err) {
    return { status: "error", error: err.message };
  }

  if (!sendResult || sendResult.successCount === 0) {
    // Dispatch failed completely: DO NOT mark event as processed
    return { status: "error", reason: "FCM dispatch failed for all devices" };
  }

  // Handle invalid / unregistered FCM tokens gracefully
  if (sendResult.failureCount > 0 && Array.isArray(sendResult.responses)) {
    for (let i = 0; i < sendResult.responses.length; i++) {
      const resp = sendResult.responses[i];
      if (!resp.success && resp.error) {
        const errCode = resp.error.code;
        if (
          errCode === "messaging/invalid-registration-token" ||
          errCode === "messaging/registration-token-not-registered"
        ) {
          const deviceDocId = validDevices[i].docId;
          await db
            .collection("users")
            .doc(userId)
            .collection("devices")
            .doc(deviceDocId)
            .set({ enabled: false, fcmToken: null }, { merge: true });
        }
      }
    }
  }

  // 7. Mark event as processed ONLY AFTER successful FCM dispatch
  const nowStamp = serverTimestamp ? serverTimestamp() : new Date().toISOString();
  await eventRef.set({
    eventId,
    scheduleId,
    version: taskVersion,
    eventType,
    processedAt: nowStamp,
  });

  return {
    status: "success",
    eventId,
    version: taskVersion,
    successCount: sendResult.successCount,
    failureCount: sendResult.failureCount,
  };
}

module.exports = {
  calculateScheduleEvents,
  validateTaskExecution,
  processScheduledFcmDispatch,
};
