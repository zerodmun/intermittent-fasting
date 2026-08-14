const { calculateScheduleEvents, validateTaskExecution } = require("../schedule_calculator");

describe("Notification Backend Schedule Calculator & Task Validation Tests", () => {
  const userId = "user_test_001";
  const scheduleId = "fasting_schedule_001";
  const baseDateStr = "2026-08-11T12:00:00.000+07:00"; // Asia/Jakarta reference time

  test("1, 2, 3, 4, 5, 6 & 12: Calculates exact 4 events for overnight schedule in Asia/Jakarta timezone", () => {
    const events = calculateScheduleEvents({
      userId,
      scheduleId,
      version: 3,
      startTime: "17:00",
      endTime: "09:00",
      reminderBeforeStart: 10,
      reminderBeforeEnd: 10,
      timezone: "Asia/Jakarta",
      baseDateTime: baseDateStr,
    });

    expect(events).toHaveLength(4);

    const startReminder = events.find((e) => e.eventType === "fasting_start_reminder");
    const start = events.find((e) => e.eventType === "fasting_start");
    const endReminder = events.find((e) => e.eventType === "fasting_end_reminder");
    const end = events.find((e) => e.eventType === "fasting_end");

    // 16:50 today
    expect(startReminder.scheduledTime).toContain("2026-08-11T16:50:00");
    expect(startReminder.eventId).toEqual("fasting_schedule_001_v3_fasting_start_reminder");

    // 17:00 today
    expect(start.scheduledTime).toContain("2026-08-11T17:00:00");
    expect(start.eventId).toEqual("fasting_schedule_001_v3_fasting_start");

    // 08:50 next day
    expect(endReminder.scheduledTime).toContain("2026-08-12T08:50:00");
    expect(endReminder.eventId).toEqual("fasting_schedule_001_v3_fasting_end_reminder");

    // 09:00 next day
    expect(end.scheduledTime).toContain("2026-08-12T09:00:00");
    expect(end.eventId).toEqual("fasting_schedule_001_v3_fasting_end");
  });

  test("7. Validates task execution when versions match and schedule enabled", () => {
    const doc = { enabled: true, version: 3 };
    const validation = validateTaskExecution(doc, 3, false);
    expect(validation.valid).toBe(true);
  });

  test("8. Rejects task execution when schedule is disabled", () => {
    const doc = { enabled: false, version: 3 };
    const validation = validateTaskExecution(doc, 3, false);
    expect(validation.valid).toBe(false);
    expect(validation.reason).toContain("Schedule is disabled");
  });

  test("9. Rejects stale task when Firestore version has changed (e.g. task v3 vs doc v4)", () => {
    const doc = { enabled: true, version: 4 }; // User updated schedule to v4
    const validation = validateTaskExecution(doc, 3, false); // Task is v3
    expect(validation.valid).toBe(false);
    expect(validation.reason).toContain("Stale task");
  });

  test("10. Rejects duplicate task execution when eventId has already been processed", () => {
    const doc = { enabled: true, version: 3 };
    const validation = validateTaskExecution(doc, 3, true); // Already processed
    expect(validation.valid).toBe(false);
    expect(validation.reason).toContain("Duplicate task");
  });

  test("11. Schedule update generates new deterministic eventIds for version 4", () => {
    const eventsV4 = calculateScheduleEvents({
      userId,
      scheduleId,
      version: 4,
      startTime: "18:00",
      endTime: "10:00",
      timezone: "Asia/Jakarta",
      baseDateTime: baseDateStr,
    });

    const startV4 = eventsV4.find((e) => e.eventType === "fasting_start");
    expect(startV4.eventId).toEqual("fasting_schedule_001_v4_fasting_start");
    expect(startV4.version).toEqual(4);
    expect(startV4.scheduledTime).toContain("2026-08-11T18:00:00");
  });
});
