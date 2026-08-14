const { processScheduledFcmDispatch } = require("../schedule_calculator");

describe("FCM Multicast Dispatcher & Idempotency Backend Tests", () => {
  const userId = "user_test_fcm";
  const scheduleId = "fasting_schedule_001";
  const version = 3;
  const eventType = "fasting_start";
  const eventId = "fasting_schedule_001_v3_fasting_start";
  const scheduledTime = "2026-08-11T17:00:00.000+07:00";

  let dbMock;
  let messagingMock;
  let scheduleDocStore;
  let eventDocStore;
  let deviceDocStore;

  beforeEach(() => {
    scheduleDocStore = { enabled: true, version: 3 };
    eventDocStore = {};
    deviceDocStore = {
      device_1: { enabled: true, fcmToken: "token_device_1" },
      device_2: { enabled: true, fcmToken: "token_device_2" },
      device_disabled: { enabled: false, fcmToken: "token_disabled" },
      device_empty: { enabled: true, fcmToken: "" },
    };

    dbMock = {
      collection: (colName) => ({
        doc: (docId1) => ({
          collection: (subColName) => ({
            doc: (docId2) => ({
              get: async () => {
                if (subColName === "notificationSchedules") {
                  return { exists: !!scheduleDocStore, data: () => scheduleDocStore };
                }
                if (subColName === "processedEvents") {
                  return { exists: !!eventDocStore[docId2], data: () => eventDocStore[docId2] };
                }
                if (subColName === "devices") {
                  return { exists: !!deviceDocStore[docId2], data: () => deviceDocStore[docId2] };
                }
                return { exists: false, data: () => null };
              },
              set: async (data, opts) => {
                if (subColName === "processedEvents") {
                  eventDocStore[docId2] = data;
                }
                if (subColName === "devices") {
                  deviceDocStore[docId2] = opts?.merge
                    ? { ...deviceDocStore[docId2], ...data }
                    : data;
                }
              },
            }),
            get: async () => {
              if (subColName === "devices") {
                const docs = Object.keys(deviceDocStore).map((id) => ({
                  id,
                  data: () => deviceDocStore[id],
                }));
                return { empty: docs.length === 0, forEach: (cb) => docs.forEach(cb) };
              }
              return { empty: true, forEach: () => {} };
            },
          }),
        }),
      }),
    };

    messagingMock = {
      sendEachForMulticast: jest.fn().mockResolvedValue({
        successCount: 2,
        failureCount: 0,
        responses: [{ success: true }, { success: true }],
      }),
    };
  });

  test("1, 5, 6: Valid FCM dispatch to multiple devices constructs payload and records idempotency", async () => {
    const res = await processScheduledFcmDispatch({
      db: dbMock,
      messaging: messagingMock,
      userId,
      scheduleId,
      version,
      eventType,
      eventId,
      scheduledTime,
    });

    expect(res.status).toEqual("success");
    expect(res.successCount).toEqual(2);

    expect(messagingMock.sendEachForMulticast).toHaveBeenCalledWith({
      data: {
        type: "fasting_notification",
        eventId,
        eventType,
        scheduleId,
        version: "3",
        scheduledTime,
        userId,
      },
      tokens: ["token_device_1", "token_device_2"],
    });

    expect(eventDocStore[eventId]).toBeDefined();
    expect(eventDocStore[eventId].eventId).toEqual(eventId);
  });

  test("2 & 3: Ignores disabled devices and empty FCM tokens", async () => {
    await processScheduledFcmDispatch({
      db: dbMock,
      messaging: messagingMock,
      userId,
      scheduleId,
      version,
      eventType,
      eventId,
      scheduledTime,
    });

    const callPayload = messagingMock.sendEachForMulticast.mock.calls[0][0];
    expect(callPayload.tokens).not.toContain("token_disabled");
    expect(callPayload.tokens).not.toContain("");
  });

  test("4: Invalid/unregistered token responses disable token in Firestore", async () => {
    messagingMock.sendEachForMulticast.mockResolvedValueOnce({
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true },
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
      ],
    });

    await processScheduledFcmDispatch({
      db: dbMock,
      messaging: messagingMock,
      userId,
      scheduleId,
      version,
      eventType,
      eventId,
      scheduledTime,
    });

    expect(deviceDocStore.device_2.enabled).toBe(false);
    expect(deviceDocStore.device_2.fcmToken).toBeNull();
  });

  test("7: Complete FCM dispatch failure does NOT mark event as processed", async () => {
    messagingMock.sendEachForMulticast.mockResolvedValueOnce({
      successCount: 0,
      failureCount: 2,
      responses: [{ success: false }, { success: false }],
    });

    const res = await processScheduledFcmDispatch({
      db: dbMock,
      messaging: messagingMock,
      userId,
      scheduleId,
      version,
      eventType,
      eventId,
      scheduledTime,
    });

    expect(res.status).toEqual("error");
    expect(eventDocStore[eventId]).toBeUndefined();
  });

  test("8: Stale task version is still rejected before FCM dispatch", async () => {
    scheduleDocStore.version = 4; // Firestore is v4, task is v3

    const res = await processScheduledFcmDispatch({
      db: dbMock,
      messaging: messagingMock,
      userId,
      scheduleId,
      version: 3,
      eventType,
      eventId,
      scheduledTime,
    });

    expect(res.status).toEqual("ignored");
    expect(res.reason).toContain("Stale task");
    expect(messagingMock.sendEachForMulticast).not.toHaveBeenCalled();
  });
});
