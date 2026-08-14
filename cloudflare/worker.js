/**
 * Cloudflare Worker for FOMO Fast Flow Notification Scheduler
 * Handles /device (POST), /schedule (POST), /debug/scheduler (GET),
 * and scheduled() Cron Trigger (every minute with FCM HTTP v1 dispatching).
 */

export default {
  /**
   * HTTP request router
   */
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    try {
      if (request.method === "POST" && url.pathname === "/device") {
        return await handleDevicePost(request, env);
      }
      if (request.method === "POST" && url.pathname === "/schedule") {
        return await handleSchedulePost(request, env);
      }
      if (request.method === "GET" && url.pathname === "/debug/scheduler") {
        return await handleDebugSchedulerGet(request, env);
      }
      return new Response(JSON.stringify({ error: "Not Found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  },

  /**
   * Cron Trigger handler executed every minute
   */
  async scheduled(event, env, ctx) {
    ctx.waitUntil(handleScheduledEvent(env));
  },
};

function getDb(env) {
  const db = env.fomo_db || env.DB;
  if (!db) {
    throw new Error("D1 database binding missing (expected env.fomo_db or env.DB)");
  }
  return db;
}

/**
 * Endpoint: POST /device
 * Stores or updates device FCM token in D1 database
 */
async function handleDevicePost(request, env) {
  const body = await request.json();
  const { userId, deviceId, fcmToken, platform, appVersion } = body || {};

  if (!userId || !deviceId || !fcmToken) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const db = getDb(env);
  const nowIso = new Date().toISOString();

  await db.prepare(
    `INSERT INTO devices (id, user_id, fcm_token, platform, app_version, enabled, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, ?)
     ON CONFLICT(id) DO UPDATE SET
       user_id = excluded.user_id,
       fcm_token = excluded.fcm_token,
       platform = excluded.platform,
       app_version = excluded.app_version,
       enabled = 1,
       updated_at = excluded.updated_at`
  )
    .bind(deviceId, userId, fcmToken, platform || "android", appVersion || "1.0.0", nowIso)
    .run();

  return new Response(JSON.stringify({ status: "success", deviceId }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Endpoint: POST /schedule
 * Stores or updates user fasting schedule in D1 database
 */
async function handleSchedulePost(request, env) {
  const body = await request.json();
  const {
    scheduleId,
    userId,
    enabled,
    timezone,
    fastHour,
    fastMinute,
    eatHour,
    eatMinute,
    reminderBeforeStart,
    reminderBeforeEnd,
    version,
  } = body || {};

  if (!scheduleId || !userId) {
    return new Response(JSON.stringify({ error: "Missing scheduleId or userId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const db = getDb(env);
  const isEnabled = enabled !== false ? 1 : 0;
  const nowIso = new Date().toISOString();

  await db.prepare(
    `INSERT INTO schedules (
       id, user_id, enabled, timezone, fast_hour, fast_minute, eat_hour, eat_minute,
       reminder_before_start, reminder_before_end, version, updated_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       user_id = excluded.user_id,
       enabled = excluded.enabled,
       timezone = excluded.timezone,
       fast_hour = excluded.fast_hour,
       fast_minute = excluded.fast_minute,
       eat_hour = excluded.eat_hour,
       eat_minute = excluded.eat_minute,
       reminder_before_start = excluded.reminder_before_start,
       reminder_before_end = excluded.reminder_before_end,
       version = excluded.version,
       updated_at = excluded.updated_at`
  )
    .bind(
      scheduleId,
      userId,
      isEnabled,
      timezone || "Asia/Jakarta",
      fastHour ?? 17,
      fastMinute ?? 0,
      eatHour ?? 9,
      eatMinute ?? 0,
      reminderBeforeStart ?? 10,
      reminderBeforeEnd ?? 10,
      version ?? 1,
      nowIso
    )
    .run();

  return new Response(JSON.stringify({ status: "success", scheduleId, version }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Cron Execution Engine
 * Evaluates enabled schedules in D1 every minute against Asia/Jakarta local time,
 * sends FCM HTTP v1 notifications to registered device tokens, and records idempotency.
 */
export async function handleScheduledEvent(env) {
  const summary = { processed: 0, dueEvents: [], errors: [] };

  try {
    const db = getDb(env);
    const jakartaTime = getJakartaTime(new Date());
    console.log(`[Scheduler] Checking schedules`);

    // 1. Read all enabled schedules from D1
    const { results: schedules } = await db.prepare(
      `SELECT * FROM schedules WHERE enabled = 1`
    ).all();

    if (!schedules || schedules.length === 0) {
      return summary;
    }

    let googleAccessToken = null;
    const serviceAccount = getServiceAccount(env);
    const projectId = serviceAccount?.project_id || "fast-flow-f3bae";

    // 2. Process each enabled schedule
    for (const schedule of schedules) {
      try {
        const events = calculateDueEventsForSchedule(schedule, jakartaTime);

        for (const event of events) {
          if (!event.isDue) continue;

          // Check if event has already been processed in D1
          const isProcessed = await isEventAlreadyProcessed(db, event.eventId);
          if (isProcessed) {
            continue;
          }

          console.log(
            `[Scheduler] EVENT DUE: User ${schedule.user_id}, Schedule ${schedule.id}, Event ${event.eventType} (v${schedule.version}), EventID ${event.eventId}`
          );

          // Get enabled devices for current user
          const { results: devices } = await db.prepare(
            `SELECT id, fcm_token FROM devices WHERE user_id = ? AND enabled = 1 AND fcm_token IS NOT NULL AND fcm_token != ''`
          )
            .bind(schedule.user_id)
            .all();

          if (!devices || devices.length === 0) {
            console.log(`[Scheduler] No enabled FCM devices found for user ${schedule.user_id}`);
            continue;
          }

          // Fetch Google OAuth2 Access Token lazily
          if (!googleAccessToken) {
            try {
              googleAccessToken = await getGoogleAccessToken(env);
            } catch (tokenErr) {
              console.error(`[Scheduler] Failed obtaining Google Access Token: ${tokenErr.message}`);
              summary.errors.push(tokenErr.message);
              break;
            }
          }

          const fcmPayload = {
            type: String(event.eventType),
            scheduleId: String(schedule.id),
            version: String(schedule.version),
            eventId: String(event.eventId),
          };

          let successCount = 0;

          // Dispatch FCM message to each registered device token
          for (const device of devices) {
            try {
              await sendFcmMessage(googleAccessToken, projectId, device.fcm_token, fcmPayload);
              successCount++;
            } catch (fcmErr) {
              console.error(`[Scheduler] FCM dispatch error for device ${device.id}: ${fcmErr.message}`);
            }
          }

          // Record in processed_events ONLY AFTER successful FCM dispatch
          if (successCount > 0) {
            await recordProcessedEvent(db, {
              eventId: event.eventId,
              scheduleId: schedule.id,
              userId: schedule.user_id,
              eventType: event.eventType,
              version: schedule.version,
            });

            console.log(`[Scheduler] FCM sent for event ${event.eventId} (${successCount} devices)`);
            console.log(`[Scheduler] Event processed ${event.eventId}`);

            summary.dueEvents.push({
              eventId: event.eventId,
              userId: schedule.user_id,
              eventType: event.eventType,
              version: schedule.version,
            });
            summary.processed++;
          } else {
            console.error(`[Scheduler] FCM dispatch failed for all devices for event ${event.eventId}. Not marking as processed.`);
          }
        }
      } catch (scheduleErr) {
        console.error(`[Scheduler] Error processing schedule ${schedule.id}: ${scheduleErr.message}`);
        summary.errors.push(`Schedule ${schedule.id}: ${scheduleErr.message}`);
      }
    }
  } catch (err) {
    console.error(`[Scheduler] Cron execution failed: ${err.message}`);
    summary.errors.push(err.message);
  }

  return summary;
}

/**
 * Returns current Asia/Jakarta Date and Time parts using Intl.DateTimeFormat
 */
export function getJakartaTime(date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jakarta",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });

  const parts = {};
  for (const part of formatter.formatToParts(date)) {
    if (part.type !== "literal") {
      parts[part.type] = part.value;
    }
  }

  let hour = parseInt(parts.hour, 10);
  if (hour === 24) hour = 0;

  const month = parts.month;
  const day = parts.day;
  const year = parts.year;
  const minute = parseInt(parts.minute, 10);

  const todayMs = new Date(`${year}-${month}-${day}T00:00:00+07:00`).getTime();
  const yesterdayDate = new Date(todayMs - 86400000);
  const tomorrowDate = new Date(todayMs + 86400000);

  const formatDateStr = (d) => {
    const f = new Intl.DateTimeFormat("en-US", {
      timeZone: "Asia/Jakarta",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    const p = {};
    for (const item of f.formatToParts(d)) {
      if (item.type !== "literal") p[item.type] = item.value;
    }
    return `${p.year}-${p.month}-${p.day}`;
  };

  return {
    year,
    month,
    day,
    hour,
    minute,
    todayDateStr: `${year}-${month}-${day}`,
    yesterdayDateStr: formatDateStr(yesterdayDate),
    tomorrowDateStr: formatDateStr(tomorrowDate),
    formatted: `${year}-${month}-${day} ${parts.hour}:${parts.minute}:${parts.second} (Asia/Jakarta)`,
  };
}

/**
 * Calculates whether any of the four fasting events match current Jakarta time
 */
export function calculateDueEventsForSchedule(schedule, jakartaTime) {
  const fastHour = Number(schedule.fast_hour);
  const fastMin = Number(schedule.fast_minute);
  const eatHour = Number(schedule.eat_hour);
  const eatMin = Number(schedule.eat_minute);
  const reminderBeforeStart = Number(schedule.reminder_before_start || 10);
  const reminderBeforeEnd = Number(schedule.reminder_before_end || 10);

  const curHour = jakartaTime.hour;
  const curMin = jakartaTime.minute;

  const events = [];

  // 1. fasting_start
  const startEventDate = jakartaTime.todayDateStr;
  events.push({
    eventType: "fasting_start",
    eventId: `${schedule.id}_v${schedule.version}_fasting_start_${startEventDate}`,
    isDue: curHour === fastHour && curMin === fastMin,
  });

  // 2. fasting_start_reminder
  const startTotalMin = fastHour * 60 + fastMin;
  let remStartTotalMin = startTotalMin - reminderBeforeStart;
  let remStartDate = startEventDate;
  if (remStartTotalMin < 0) {
    remStartTotalMin += 1440;
    remStartDate = jakartaTime.yesterdayDateStr;
  }
  const remStartHour = Math.floor(remStartTotalMin / 60);
  const remStartMin = remStartTotalMin % 60;

  events.push({
    eventType: "fasting_start_reminder",
    eventId: `${schedule.id}_v${schedule.version}_fasting_start_reminder_${remStartDate}`,
    isDue: curHour === remStartHour && curMin === remStartMin,
  });

  // 3. fasting_end (Overnight check: if eat time <= fast time, end occurs on next day)
  const isOvernight = eatHour < fastHour || (eatHour === fastHour && eatMin <= fastMin);
  const endEventDate = isOvernight ? jakartaTime.tomorrowDateStr : jakartaTime.todayDateStr;

  events.push({
    eventType: "fasting_end",
    eventId: `${schedule.id}_v${schedule.version}_fasting_end_${endEventDate}`,
    isDue: curHour === eatHour && curMin === eatMin,
  });

  // 4. fasting_end_reminder
  const endTotalMin = eatHour * 60 + eatMin;
  let remEndTotalMin = endTotalMin - reminderBeforeEnd;
  let remEndDate = endEventDate;
  if (remEndTotalMin < 0) {
    remEndTotalMin += 1440;
    remEndDate = isOvernight ? jakartaTime.todayDateStr : jakartaTime.yesterdayDateStr;
  }
  const remEndHour = Math.floor(remEndTotalMin / 60);
  const remEndMin = remEndTotalMin % 60;

  events.push({
    eventType: "fasting_end_reminder",
    eventId: `${schedule.id}_v${schedule.version}_fasting_end_reminder_${remEndDate}`,
    isDue: curHour === remEndHour && curMin === remEndMin,
  });

  return events;
}

/**
 * Checks if event has already been recorded in processed_events D1 table.
 * Throws explicit error if processed_events table does not exist.
 */
export async function isEventAlreadyProcessed(db, eventId) {
  try {
    const row = await db
      .prepare(`SELECT event_id FROM processed_events WHERE event_id = ? LIMIT 1`)
      .bind(eventId)
      .first();
    return !!row;
  } catch (err) {
    if (err.message && err.message.includes("no such table")) {
      throw new Error(
        `D1 table 'processed_events' does not exist. Please execute D1 migration: CREATE TABLE processed_events (event_id TEXT PRIMARY KEY, schedule_id TEXT NOT NULL, user_id TEXT NOT NULL, event_type TEXT NOT NULL, version INTEGER NOT NULL, processed_at TEXT NOT NULL);`
      );
    }
    throw err;
  }
}

/**
 * Records processed event in processed_events D1 table.
 */
export async function recordProcessedEvent(db, { eventId, scheduleId, userId, eventType, version }) {
  const nowIso = new Date().toISOString();
  await db
    .prepare(
      `INSERT INTO processed_events (event_id, schedule_id, user_id, event_type, version, processed_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
    .bind(eventId, scheduleId, userId, eventType, version, nowIso)
    .run();
}

/**
 * Helper to get Google OAuth2 Access Token for FCM HTTP v1 using Service Account Credentials from env
 */
async function getGoogleAccessToken(env) {
  const serviceAccount = getServiceAccount(env);
  if (!serviceAccount || !serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error("Missing Firebase Service Account credentials in env");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  const signature = await signRsaSha256(unsignedToken, serviceAccount.private_key);
  const jwt = `${unsignedToken}.${signature}`;

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const errText = await tokenResp.text();
    throw new Error(`Failed getting Google OAuth2 token: ${tokenResp.status} - ${errText}`);
  }

  const data = await tokenResp.json();
  return data.access_token;
}

function getServiceAccount(env) {
  if (env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      return typeof env.FIREBASE_SERVICE_ACCOUNT === "string"
        ? JSON.parse(env.FIREBASE_SERVICE_ACCOUNT)
        : env.FIREBASE_SERVICE_ACCOUNT;
    } catch (_) {}
  }
  if (env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
    return {
      client_email: env.FIREBASE_CLIENT_EMAIL,
      private_key: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      project_id: env.FIREBASE_PROJECT_ID || "fast-flow-f3bae",
    };
  }
  return null;
}

function base64UrlEncode(strOrBuffer) {
  let bytes;
  if (typeof strOrBuffer === "string") {
    bytes = new TextEncoder().encode(strOrBuffer);
  } else {
    bytes = new Uint8Array(strOrBuffer);
  }
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function signRsaSha256(data, pemKey) {
  const cleanPem = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(cleanPem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(data)
  );

  return base64UrlEncode(signature);
}

/**
 * Sends FCM DATA notification via Firebase HTTP v1 API
 */
async function sendFcmMessage(accessToken, projectId, token, payloadData) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const body = {
    message: {
      token: token,
      data: payloadData,
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`FCM HTTP v1 error ${resp.status}: ${errText}`);
  }

  return await resp.json();
}

/**
 * Endpoint: GET /debug/scheduler
 * Returns current Asia/Jakarta time, active schedules, target times, event status, and eventIds
 * without processing events, saving to D1, or triggering notifications.
 */
export async function handleDebugSchedulerGet(request, env) {
  const jakartaTime = getJakartaTime(new Date());
  const db = getDb(env);

  const { results: schedules } = await db.prepare(
    `SELECT * FROM schedules WHERE enabled = 1`
  ).all();

  const scheduleSummaries = (schedules || []).map((schedule) => {
    const events = calculateDueEventsForSchedule(schedule, jakartaTime);

    const eventStatusMap = {};
    const eventIdsMap = {};

    events.forEach((ev) => {
      eventStatusMap[ev.eventType] = ev.isDue;
      eventIdsMap[ev.eventType] = ev.eventId;
    });

    const fastHourStr = String(schedule.fast_hour).padStart(2, "0");
    const fastMinStr = String(schedule.fast_minute).padStart(2, "0");
    const eatHourStr = String(schedule.eat_hour).padStart(2, "0");
    const eatMinStr = String(schedule.eat_minute).padStart(2, "0");

    const startTotalMin = Number(schedule.fast_hour) * 60 + Number(schedule.fast_minute);
    let remStartTotal = startTotalMin - Number(schedule.reminder_before_start || 10);
    if (remStartTotal < 0) remStartTotal += 1440;
    const fastRemHourStr = String(Math.floor(remStartTotal / 60)).padStart(2, "0");
    const fastRemMinStr = String(remStartTotal % 60).padStart(2, "0");

    const endTotalMin = Number(schedule.eat_hour) * 60 + Number(schedule.eat_minute);
    let remEndTotal = endTotalMin - Number(schedule.reminder_before_end || 10);
    if (remEndTotal < 0) remEndTotal += 1440;
    const eatRemHourStr = String(Math.floor(remEndTotal / 60)).padStart(2, "0");
    const eatRemMinStr = String(remEndTotal % 60).padStart(2, "0");

    return {
      scheduleId: schedule.id,
      userId: schedule.user_id,
      version: schedule.version,
      fastingStart: `${fastHourStr}:${fastMinStr}`,
      fastingStartReminder: `${fastRemHourStr}:${fastRemMinStr}`,
      fastingEnd: `${eatHourStr}:${eatMinStr}`,
      fastingEndReminder: `${eatRemHourStr}:${eatRemMinStr}`,
      events: eventStatusMap,
      eventIds: eventIdsMap,
    };
  });

  return new Response(
    JSON.stringify({
      success: true,
      timezone: "Asia/Jakarta",
      currentTime: `${jakartaTime.todayDateStr} ${String(jakartaTime.hour).padStart(2, "0")}:${String(jakartaTime.minute).padStart(2, "0")}`,
      schedules: scheduleSummaries,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
}
