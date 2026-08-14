const {
  getJakartaTime,
  calculateDueEventsForSchedule,
  isEventAlreadyProcessed,
  recordProcessedEvent,
  handleDebugSchedulerGet,
} = require("../../cloudflare/worker.js");

describe("Cloudflare Worker scheduled() Cron & Timezone Calculation Tests", () => {
  const schedule = {
    id: "fasting_schedule_001",
    user_id: "user_test_001",
    enabled: 1,
    timezone: "Asia/Jakarta",
    fast_hour: 17,
    fast_minute: 0,
    eat_hour: 9,
    eat_minute: 0,
    reminder_before_start: 10,
    reminder_before_end: 10,
    version: 5,
  };

  test("getJakartaTime correctly extracts Asia/Jakarta parts using Intl.DateTimeFormat", () => {
    const testDate = new Date("2026-08-12T09:50:00.000Z"); // 16:50 in UTC+7 (Asia/Jakarta)
    const jkt = getJakartaTime(testDate);

    expect(jkt.todayDateStr).toEqual("2026-08-12");
    expect(jkt.hour).toEqual(16);
    expect(jkt.minute).toEqual(50);
  });

  test("Calculates fasting_start_reminder as due at 16:50 today", () => {
    const jkt = {
      hour: 16,
      minute: 50,
      todayDateStr: "2026-08-12",
      yesterdayDateStr: "2026-08-11",
      tomorrowDateStr: "2026-08-13",
    };

    const events = calculateDueEventsForSchedule(schedule, jkt);
    const startRem = events.find((e) => e.eventType === "fasting_start_reminder");

    expect(startRem.isDue).toBe(true);
    expect(startRem.eventId).toEqual("fasting_schedule_001_v5_fasting_start_reminder_2026-08-12");
  });

  test("Calculates fasting_start as due at 17:00 today", () => {
    const jkt = {
      hour: 17,
      minute: 0,
      todayDateStr: "2026-08-12",
      yesterdayDateStr: "2026-08-11",
      tomorrowDateStr: "2026-08-13",
    };

    const events = calculateDueEventsForSchedule(schedule, jkt);
    const start = events.find((e) => e.eventType === "fasting_start");

    expect(start.isDue).toBe(true);
    expect(start.eventId).toEqual("fasting_schedule_001_v5_fasting_start_2026-08-12");
  });

  test("Calculates overnight fasting_end as due at 09:00 with tomorrow's date", () => {
    const jkt = {
      hour: 9,
      minute: 0,
      todayDateStr: "2026-08-13",
      yesterdayDateStr: "2026-08-12",
      tomorrowDateStr: "2026-08-14",
    };

    const events = calculateDueEventsForSchedule(schedule, jkt);
    const end = events.find((e) => e.eventType === "fasting_end");

    expect(end.isDue).toBe(true);
    expect(end.eventId).toEqual("fasting_schedule_001_v5_fasting_end_2026-08-14");
  });

  test("Calculates fasting_end_reminder as due at 08:50 with tomorrow's date", () => {
    const jkt = {
      hour: 8,
      minute: 50,
      todayDateStr: "2026-08-13",
      yesterdayDateStr: "2026-08-12",
      tomorrowDateStr: "2026-08-14",
    };

    const events = calculateDueEventsForSchedule(schedule, jkt);
    const endRem = events.find((e) => e.eventType === "fasting_end_reminder");

    expect(endRem.isDue).toBe(true);
    expect(endRem.eventId).toEqual("fasting_schedule_001_v5_fasting_end_reminder_2026-08-14");
  });

  test("handleDebugSchedulerGet returns debug JSON summary without modifying DB or marking events", async () => {
    const envMock = {
      DB: {
        prepare: () => ({
          all: async () => ({ results: [schedule] }),
        }),
      },
    };

    const response = await handleDebugSchedulerGet({}, envMock);
    expect(response.status).toEqual(200);

    const json = JSON.parse(await response.text());
    expect(json.success).toBe(true);
    expect(json.timezone).toEqual("Asia/Jakarta");
    expect(json.schedules).toHaveLength(1);
    expect(json.schedules[0].scheduleId).toEqual("fasting_schedule_001");
    expect(json.schedules[0].fastingStart).toEqual("17:00");
    expect(json.schedules[0].fastingStartReminder).toEqual("16:50");
    expect(json.schedules[0].fastingEnd).toEqual("09:00");
    expect(json.schedules[0].fastingEndReminder).toEqual("08:50");
    expect(json.schedules[0].events).toBeDefined();
    expect(json.schedules[0].eventIds).toBeDefined();
  });
});
