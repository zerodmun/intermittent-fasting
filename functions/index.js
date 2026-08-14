const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { CloudTasksClient } = require("@google-cloud/tasks");
const { calculateScheduleEvents, validateTaskExecution, processScheduledFcmDispatch } = require("./schedule_calculator");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();
let tasksClient;

function getTasksClient() {
  if (!tasksClient) {
    tasksClient = new CloudTasksClient();
  }
  return tasksClient;
}

/**
 * Firestore trigger: Executes when a user's notification schedule is created or updated.
 * Path: users/{userId}/notificationSchedules/{scheduleId}
 * 
 * Calculates target events in Asia/Jakarta timezone and enqueues Cloud Tasks.
 */
exports.onNotificationScheduleWrite = functions.firestore
  .document("users/{userId}/notificationSchedules/{scheduleId}")
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const scheduleId = context.params.scheduleId;

    if (!change.after.exists) {
      functions.logger.info(`Schedule ${scheduleId} deleted for user ${userId}. Skipping task scheduling.`);
      return null;
    }

    const scheduleData = change.after.data();
    const enabled = scheduleData.enabled ?? true;

    if (!enabled) {
      functions.logger.info(`Schedule ${scheduleId} is disabled for user ${userId}. Skipping task scheduling.`);
      return null;
    }

    const version = scheduleData.version ?? 1;
    const startTime = scheduleData.startTime || "17:00";
    const endTime = scheduleData.endTime || "09:00";
    const reminderBeforeStart = scheduleData.reminderBeforeStart || 10;
    const reminderBeforeEnd = scheduleData.reminderBeforeEnd || 10;
    const timezone = scheduleData.timezone || "Asia/Jakarta";
    const notificationSettings = scheduleData.notificationSettings || {};

    const events = calculateScheduleEvents({
      userId,
      scheduleId,
      version,
      startTime,
      endTime,
      reminderBeforeStart,
      reminderBeforeEnd,
      timezone,
      notificationSettings,
    });

    functions.logger.info(`Schedule ${scheduleId} (v${version}) created/updated for user ${userId}. Calculated ${events.length} events for Asia/Jakarta timezone.`);

    const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || "fast-flow-f3bae";
    const location = process.env.LOCATION_ID || "asia-southeast1";
    const queue = process.env.TASKS_QUEUE || "notification-schedule-queue";
    const serviceAccountEmail = process.env.SERVICE_ACCOUNT_EMAIL;
    const functionUrl = process.env.EXECUTE_TASK_URL;

    for (const event of events) {
      if (functionUrl && serviceAccountEmail) {
        try {
          const client = getTasksClient();
          const parent = client.queuePath(projectId, location, queue);
          const scheduledDate = new Date(event.scheduledTime);

          const task = {
            httpRequest: {
              httpMethod: "POST",
              url: functionUrl,
              headers: { "Content-Type": "application/json" },
              body: Buffer.from(JSON.stringify(event)).toString("base64"),
              oidcToken: { serviceAccountEmail },
            },
            scheduleTime: {
              seconds: Math.floor(scheduledDate.getTime() / 1000),
            },
          };

          await client.createTask({ parent, task });
          functions.logger.info(`Cloud Task enqueued: ${event.eventId} for ${event.scheduledTime}`);
        } catch (taskError) {
          functions.logger.warn(`Failed enqueuing Cloud Task for ${event.eventId} (Cloud Tasks queue or IAM permission required): ${taskError.message}`);
        }
      } else {
        functions.logger.info(`Calculated event payload ready for Cloud Tasks: ${JSON.stringify(event)} (Cloud Tasks URL/ServiceAccount env vars not set yet)`);
      }
    }

    return null;
  });

/**
 * Scheduled Cloud Task HTTP execution endpoint.
 * Validates Firestore version, enabled status, device tokens, and idempotency before FCM dispatch.
 */
exports.executeScheduledNotification = functions.https.onRequest(async (req, res) => {
  const { userId, scheduleId, version, eventType, eventId, scheduledTime } = req.body || {};

  if (!userId || !scheduleId || !version || !eventType || !eventId) {
    res.status(400).send({ error: "Invalid task payload format" });
    return;
  }

  const result = await processScheduledFcmDispatch({
    db,
    messaging,
    userId,
    scheduleId,
    version,
    eventType,
    eventId,
    scheduledTime,
    serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
  });

  if (result.status === "ignored") {
    functions.logger.info(`Task execution rejected for event ${eventId}: ${result.reason}`);
    res.status(200).send({ status: "ignored", reason: result.reason });
  } else if (result.status === "error") {
    functions.logger.error(`FCM dispatch failed for event ${eventId}: ${result.error || result.reason}`);
    res.status(500).send({ status: "error", reason: result.error || result.reason });
  } else {
    functions.logger.info(`FCM dispatch successful for event ${eventId} (v${version}). Idempotency recorded.`);
    res.status(200).send(result);
  }
});
