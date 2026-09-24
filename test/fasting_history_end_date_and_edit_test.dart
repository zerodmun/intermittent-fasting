// ignore_for_file: subtype_of_sealed_class
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/presentation/providers/fasting_providers.dart';
import 'package:fast_flow/features/history/presentation/providers/history_providers.dart';
import 'package:fast_flow/features/history/presentation/screens/history_screen.dart';

// ── Mock & Fake Implementations for Firestore & Auth ──

class FakeUser extends Fake implements User {
  final String _uid;
  final String? _email;
  FakeUser(this._uid, [this._email]);

  @override
  String get uid => _uid;

  @override
  String? get email => _email ?? '$_uid@example.com';
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _user;
  FakeFirebaseAuth([this._user]);

  void setUser(User? user) {
    _user = user;
  }

  @override
  User? get currentUser => _user;
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic> data() => _data ?? {};
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  final List<FakeDocumentSnapshot> _docs;
  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      _docs.map((d) => FakeQueryDocumentSnapshot(d.id, d.data())).toList();
}

class FakeQueryDocumentSnapshot extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final String _path;
  final Map<String, Map<String, dynamic>> _storage;
  FakeDocumentReference(this._path, this._storage);

  @override
  String get id => _path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final data = _storage[_path];
    return FakeDocumentSnapshot(id, data);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (options?.merge == true && _storage.containsKey(_path)) {
      _storage[_path] = {...?_storage[_path], ...data};
    } else {
      _storage[_path] = Map<String, dynamic>.from(data);
    }
  }

  @override
  Future<void> delete() async {
    _storage.remove(_path);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference('$_path/$collectionPath', _storage);
  }
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final String _path;
  final Map<String, Map<String, dynamic>> _storage;
  FakeCollectionReference(this._path, this._storage);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'doc_${DateTime.now().millisecondsSinceEpoch}';
    return FakeDocumentReference('$_path/$docId', _storage);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = <FakeDocumentSnapshot>[];
    final prefix = '$_path/';
    for (final entry in _storage.entries) {
      if (entry.key.startsWith(prefix)) {
        final subPath = entry.key.substring(prefix.length);
        if (!subPath.contains('/')) {
          docs.add(FakeDocumentSnapshot(subPath, entry.value));
        }
      }
    }
    return FakeQuerySnapshot(docs);
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> storage = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(collectionPath, storage);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String documentPath) {
    return FakeDocumentReference(documentPath, storage);
  }
}

class TestCurrentDateNotifier extends CurrentDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('fasting_history_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    FastingEngine().dispose();
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth();
    AuthService.instance.setMockInstances(auth: fakeAuth, firestore: fakeFirestore);
    HiveService.instance.setMockFirestore(fakeFirestore);
    UserDataMigrationService.instance.setMockFirestore(fakeFirestore);
    FcmService.instance.resetMemoryCache();
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
    await HiveService.instance.settingsBox.clear();
  });

  tearDown(() {
    FastingEngine().dispose();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Fasting History Date Display, Time Editing & Firestore Sync Hardening Suite', () {
    test('1 & 2. Fasting session spanning midnight uses fastingEndAt for date grouping (3 Sep not 2 Sep)', () async {
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      final record = FastingRecord(
        id: 'fasting_001',
        planName: '16:8',
        fastingMinutes: end.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );

      await HiveService.instance.saveFastingRecord(record);

      expect(record.fastingStartAt, equals(start));
      expect(record.fastingEndAt, equals(end));
      expect(record.fastingEndAt.day, equals(3));
      expect(record.fastingEndAt.month, equals(9));
      expect(record.fastingEndAt.year, equals(2026));

      final all = HiveService.instance.allFastingRecords;
      expect(all.length, equals(1));
      expect(all.first.fastingEndAt, equals(end));
    });

    test('3 & 4. Duration is calculated correctly across midnight and formatted as spelled-out string', () {
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      final record = FastingRecord(
        id: 'fasting_002',
        planName: '16:8',
        fastingMinutes: end.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );

      expect(record.duration.inMinutes, equals(17 * 60 + 40));
      expect(record.duration.toDetailedSpelledOut, equals('17 hours 40 minutes'));
    });

    test('5. Editing end time to 11:00 updates duration to 18 hours', () async {
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      final record = FastingRecord(
        id: 'fasting_003',
        planName: '16:8',
        fastingMinutes: end.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      final container = ProviderContainer();
      final updatedEnd = DateTime(2026, 9, 3, 11, 0);

      final success = container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'fasting_003',
        startTime: start,
        endTime: updatedEnd,
        status: 'completed',
      );

      expect(success, isTrue);

      final saved = HiveService.instance.fastingRecordsBox.get('fasting_003');
      expect(saved, isNotNull);
      expect(saved!.fastingEndAt, equals(updatedEnd));
      expect(saved.fastingMinutes, equals(18 * 60));
      expect(saved.duration.toDetailedSpelledOut, equals('18 hours'));

      container.dispose();
    });

    test('6. Editing end date from 3 Sep to 4 Sep immediately moves record in History sort order', () async {
      final start = DateTime(2026, 9, 2, 17, 0);
      final initialEnd = DateTime(2026, 9, 3, 10, 40);
      final recordA = FastingRecord(
        id: 'fasting_004_A',
        planName: '16:8',
        fastingMinutes: initialEnd.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: initialEnd,
        status: 'completed',
      );

      final recordB = FastingRecord(
        id: 'fasting_004_B',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 3, 18, 0),
        endTime: DateTime(2026, 9, 4, 10, 0),
        status: 'completed',
      );

      await HiveService.instance.saveFastingRecord(recordA);
      await HiveService.instance.saveFastingRecord(recordB);

      var records = HiveService.instance.allFastingRecords;
      expect(records.first.id, equals('fasting_004_B'));
      expect(records.last.id, equals('fasting_004_A'));

      final newEndA = DateTime(2026, 9, 5, 8, 0);
      final container = ProviderContainer();
      container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'fasting_004_A',
        startTime: start,
        endTime: newEndA,
        status: 'completed',
      );

      records = HiveService.instance.allFastingRecords;
      expect(records.first.id, equals('fasting_004_A'));
      expect(records.first.fastingEndAt.day, equals(5));

      container.dispose();
    });

    test('7, 8 & 9. Editing preserves existing recordId without duplicate records', () async {
      final record = FastingRecord(
        id: 'fasting_unique_005',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 1, 18, 0),
        endTime: DateTime(2026, 9, 2, 10, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);
      expect(HiveService.instance.fastingRecordsBox.get('fasting_unique_005'), isNotNull);

      final container = ProviderContainer();
      final success = container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'fasting_unique_005',
        startTime: DateTime(2026, 9, 1, 19, 0),
        endTime: DateTime(2026, 9, 2, 11, 0),
        status: 'completed',
        note: 'Updated Note',
      );

      expect(success, isTrue);
      expect(HiveService.instance.fastingRecordsBox.values.where((r) => r.id == 'fasting_unique_005').length, equals(1));
      final edited = HiveService.instance.fastingRecordsBox.get('fasting_unique_005');
      expect(edited?.id, equals('fasting_unique_005'));
      expect(edited?.note, equals('Updated Note'));
      expect(edited?.fastingMinutes, equals(960));

      container.dispose();
    });

    test('10. Guest edits perform zero Firestore writes and maintain local state safely', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', null);

      final record = FastingRecord(
        id: 'guest_rec_006',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 2, 18, 0),
        endTime: DateTime(2026, 9, 3, 10, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      final container = ProviderContainer();
      final success = container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'guest_rec_006',
        startTime: DateTime(2026, 9, 2, 17, 0),
        endTime: DateTime(2026, 9, 3, 10, 0),
        status: 'completed',
      );

      expect(success, isTrue);
      expect(UserDataMigrationService.instance.boundFirebaseUid, isNull);
      expect(fakeFirestore.storage.isEmpty, isTrue);

      container.dispose();
    });

    test('11. Local edit is saved even if cloud sync is unavailable', () async {
      final record = FastingRecord(
        id: 'offline_rec_007',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 1, 18, 0),
        endTime: DateTime(2026, 9, 2, 10, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      final container = ProviderContainer();
      final success = container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'offline_rec_007',
        startTime: DateTime(2026, 9, 1, 17, 0),
        endTime: DateTime(2026, 9, 2, 10, 0),
        status: 'completed',
        note: 'Offline saved',
      );

      expect(success, isTrue);
      final edited = HiveService.instance.fastingRecordsBox.get('offline_rec_007');
      expect(edited?.note, equals('Offline saved'));
      expect(edited?.fastingMinutes, equals(1020));

      container.dispose();
    });

    test('12. Multiple fasting records ending on the same date remain separate records', () async {
      final rec1 = FastingRecord(
        id: 'rec_same_day_1',
        planName: '16:8',
        fastingMinutes: 480,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 3, 0, 0),
        endTime: DateTime(2026, 9, 3, 8, 0),
        status: 'completed',
      );
      final rec2 = FastingRecord(
        id: 'rec_same_day_2',
        planName: '16:8',
        fastingMinutes: 360,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 3, 12, 0),
        endTime: DateTime(2026, 9, 3, 18, 0),
        status: 'completed',
      );

      await HiveService.instance.saveFastingRecord(rec1);
      await HiveService.instance.saveFastingRecord(rec2);

      final allRecords = HiveService.instance.allFastingRecords;
      expect(allRecords.length, equals(2));
      expect(allRecords.where((r) => r.fastingEndAt.day == 3).length, equals(2));
      expect(allRecords.map((r) => r.id).toSet().length, equals(2));
    });

    test('13. Validation rejects invalid end-before-start datetime values', () async {
      final record = FastingRecord(
        id: 'invalid_range_008',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 2, 18, 0),
        endTime: DateTime(2026, 9, 3, 10, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      final container = ProviderContainer();
      final success = container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'invalid_range_008',
        startTime: DateTime(2026, 9, 3, 18, 0),
        endTime: DateTime(2026, 9, 2, 10, 0),
        status: 'completed',
      );

      expect(success, isFalse);
      final unchanged = HiveService.instance.fastingRecordsBox.get('invalid_range_008');
      expect(unchanged?.startTime, equals(DateTime(2026, 9, 2, 18, 0)));

      container.dispose();
    });

    testWidgets('14. HistoryScreen renders card with end date (3 September 2026)', (tester) async {
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      final record = FastingRecord(
        id: 'widget_fast_009',
        planName: '16:8',
        fastingMinutes: end.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(TestCurrentDateNotifier.new),
            historyProvider.overrideWithValue([record]),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3 September 2026'), findsOneWidget);
      expect(find.textContaining('16:8'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('15. Tapping record opens details sheet showing Fasting Start, Fasting End, and Duration', (tester) async {
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      final record = FastingRecord(
        id: 'widget_detail_010',
        planName: '16:8',
        fastingMinutes: end.difference(start).inMinutes,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(TestCurrentDateNotifier.new),
            historyProvider.overrideWithValue([record]),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final card = find.text('3 September 2026');
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Fasting Session Details'), findsOneWidget);
      expect(find.text('Fasting Start'), findsOneWidget);
      expect(find.text('2 September 2026'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      expect(find.text('Fasting End'), findsOneWidget);
      expect(find.text('10:40'), findsOneWidget);
      expect(find.text('17 hours 40 minutes'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    test('16. Canonical Firestore schema on write: Only canonical fields written, NO duplicate legacy fields', () async {
      fakeAuth.setUser(FakeUser('auth_user_100', 'user100@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_100');

      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);
      final record = FastingRecord(
        id: 'canonical_rec_100',
        planName: '16:8',
        fastingMinutes: 1060,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
        note: 'Canonical test',
      );

      await HiveService.instance.saveFastingRecord(record);

      final firestoreDoc = fakeFirestore.storage['users/auth_user_100/fastingRecords/canonical_rec_100'];
      expect(firestoreDoc, isNotNull);

      // Verify canonical fields exist
      expect(firestoreDoc!['recordId'], equals('canonical_rec_100'));
      expect(firestoreDoc['duration'], equals(1060));
      expect(firestoreDoc['fastingStartAt'], isA<Timestamp>());
      expect(firestoreDoc['fastingEndAt'], isA<Timestamp>());
      expect(firestoreDoc['updatedAt'], isA<Timestamp>());
      expect(firestoreDoc['isDeleted'], isFalse);
      expect(firestoreDoc['syncStatus'], equals('synced'));

      // Verify legacy fields are NOT written
      expect(firestoreDoc.containsKey('startTime'), isFalse);
      expect(firestoreDoc.containsKey('endTime'), isFalse);
      expect(firestoreDoc.containsKey('fastingMinutes'), isFalse);
      expect(firestoreDoc.containsKey('id'), isFalse);
    });

    test('17. Stable recordId: Editing a record retains document ID and updates canonical fields', () async {
      fakeAuth.setUser(FakeUser('auth_user_101', 'user101@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_101');

      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);
      final record = FastingRecord(
        id: 'stable_rec_101',
        planName: '16:8',
        fastingMinutes: 1060,
        eatingMinutes: 480,
        startTime: start,
        endTime: end,
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      final container = ProviderContainer();
      final updatedEnd = DateTime(2026, 9, 3, 11, 0);
      container.read(fastingStateNotifierProvider.notifier).editFastingRecord(
        id: 'stable_rec_101',
        startTime: start,
        endTime: updatedEnd,
        status: 'completed',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      final firestoreDoc = fakeFirestore.storage['users/auth_user_101/fastingRecords/stable_rec_101'];
      expect(firestoreDoc, isNotNull);
      expect(firestoreDoc!['recordId'], equals('stable_rec_101'));
      expect(firestoreDoc['duration'], equals(18 * 60));

      // Verify no duplicate document ID created for this record
      final matchingDocs = fakeFirestore.storage.keys.where((k) => k.contains('stable_rec_101'));
      expect(matchingDocs.length, equals(1));

      FastingEngine().dispose();
      container.dispose();
    });

    test('18. Separate metadata: Fasting timestamps are distinct from updatedAt and syncedAt', () async {
      fakeAuth.setUser(FakeUser('auth_user_102', 'user102@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_102');

      final fastingStart = DateTime.utc(2026, 9, 1, 18, 0);
      final fastingEnd = DateTime.utc(2026, 9, 2, 10, 0);
      final updatedAt = DateTime.utc(2026, 9, 2, 12, 30);
      final record = FastingRecord(
        id: 'meta_rec_102',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: fastingStart,
        endTime: fastingEnd,
        status: 'completed',
        createdAt: DateTime.utc(2026, 9, 2, 10, 0),
        updatedAt: updatedAt,
      );
      await HiveService.instance.saveFastingRecord(record);

      final firestoreDoc = fakeFirestore.storage['users/auth_user_102/fastingRecords/meta_rec_102']!;
      final fStartTs = (firestoreDoc['fastingStartAt'] as Timestamp).toDate();
      final updatedAtTs = (firestoreDoc['updatedAt'] as Timestamp).toDate();

      expect(fStartTs.isAtSameMomentAs(fastingStart), isTrue);
      expect(updatedAtTs.isAtSameMomentAs(updatedAt), isTrue);
      expect(firestoreDoc['syncedAt'], isNotNull);
    });

    test('19. Backward-compatible read: Hydrates documents with legacy fields (startTime, endTime, fastingMinutes, id)', () async {
      fakeAuth.setUser(FakeUser('auth_user_legacy', 'legacy@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_legacy');

      // Setup user document and legacy fasting record in Firestore
      fakeFirestore.storage['users/auth_user_legacy'] = {
        'uid': 'auth_user_legacy',
        'email': 'legacy@example.com',
        'profile': {
          'name': 'Legacy Schema User',
          'gender': 'female',
          'ageYears': 30,
          'heightCm': 165.0,
          'weightKg': 58.0,
          'goalWeightKg': 54.0,
          'targetBodyFat': 20.0,
          'targetWaist': 70.0,
          'targetBmi': 21.3,
          'selectedPlanId': '16-8',
          'onboardingComplete': true,
        },
      };

      final startUtc = DateTime.utc(2026, 9, 2, 10, 0);
      final endUtc = DateTime.utc(2026, 9, 3, 3, 40);
      fakeFirestore.storage['users/auth_user_legacy/fastingRecords/old_rec_999'] = {
        'id': 'old_rec_999',
        'startTime': Timestamp.fromDate(startUtc),
        'endTime': Timestamp.fromDate(endUtc),
        'fastingMinutes': 1060,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'note': 'Legacy schema record',
      };

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'auth_user_legacy',
        email: 'legacy@example.com',
      );

      final hydrated = HiveService.instance.fastingRecordsBox.get('old_rec_999');
      expect(hydrated, isNotNull);
      expect(hydrated!.id, equals('old_rec_999'));
      expect(hydrated.fastingMinutes, equals(1060));
      expect(hydrated.fastingStartAt, equals(startUtc.toLocal()));
      expect(hydrated.fastingEndAt, equals(endUtc.toLocal()));
      expect(hydrated.note, equals('Legacy schema record'));
    });

    test('20. Stale remote snapshot protection: Local record with newer updatedAt is NOT overwritten', () async {
      fakeAuth.setUser(FakeUser('auth_user_conflict', 'conflict@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_conflict');

      // Local record edited recently at 14:00 UTC
      final localRecord = FastingRecord(
        id: 'conflict_rec_001',
        planName: '16:8',
        fastingMinutes: 1080,
        eatingMinutes: 480,
        startTime: DateTime.utc(2026, 9, 2, 17, 0),
        endTime: DateTime.utc(2026, 9, 3, 11, 0),
        status: 'completed',
        note: 'Newer local edit at 14:00',
        updatedAt: DateTime.utc(2026, 9, 3, 14, 0),
      );
      await HiveService.instance.fastingRecordsBox.put('conflict_rec_001', localRecord);

      // Remote Firestore has older version edited at 10:00 UTC
      fakeFirestore.storage['users/auth_user_conflict'] = {
        'uid': 'auth_user_conflict',
        'email': 'conflict@example.com',
        'profile': {'name': 'Conflict User', 'onboardingComplete': true},
      };
      fakeFirestore.storage['users/auth_user_conflict/fastingRecords/conflict_rec_001'] = {
        'recordId': 'conflict_rec_001',
        'fastingStartAt': Timestamp.fromDate(DateTime.utc(2026, 9, 2, 17, 0)),
        'fastingEndAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3, 10, 0)),
        'duration': 1020,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'note': 'Older remote snapshot at 10:00',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3, 10, 0)),
      };

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'auth_user_conflict',
        email: 'conflict@example.com',
      );

      final current = HiveService.instance.fastingRecordsBox.get('conflict_rec_001');
      expect(current, isNotNull);
      expect(current!.note, equals('Newer local edit at 14:00'));
      expect(current.fastingMinutes, equals(1080));
    });

    test('21. Soft delete sync: Deleting record writes isDeleted: true to Firestore and cleans up locally', () async {
      fakeAuth.setUser(FakeUser('auth_user_del', 'del@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_del');

      final record = FastingRecord(
        id: 'del_rec_001',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 1, 18, 0),
        endTime: DateTime(2026, 9, 2, 10, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);
      expect(fakeFirestore.storage.containsKey('users/auth_user_del/fastingRecords/del_rec_001'), isTrue);

      await HiveService.instance.deleteFastingRecord('del_rec_001');

      // Local box no longer contains record
      expect(HiveService.instance.fastingRecordsBox.containsKey('del_rec_001'), isFalse);

      // Remote Firestore record is soft-deleted with isDeleted: true
      final firestoreDoc = fakeFirestore.storage['users/auth_user_del/fastingRecords/del_rec_001'];
      expect(firestoreDoc, isNotNull);
      expect(firestoreDoc!['isDeleted'], isTrue);
      expect(firestoreDoc['recordId'], equals('del_rec_001'));
    });

    test('22. Soft delete hydration skip: Hydration ignores records marked isDeleted: true', () async {
      fakeAuth.setUser(FakeUser('auth_user_del_hyd', 'delhyd@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', 'auth_user_del_hyd');

      fakeFirestore.storage['users/auth_user_del_hyd'] = {
        'uid': 'auth_user_del_hyd',
        'email': 'delhyd@example.com',
        'profile': {'name': 'Del User', 'onboardingComplete': true},
      };
      fakeFirestore.storage['users/auth_user_del_hyd/fastingRecords/active_001'] = {
        'recordId': 'active_001',
        'fastingStartAt': Timestamp.fromDate(DateTime.utc(2026, 9, 2, 18, 0)),
        'fastingEndAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3, 10, 0)),
        'duration': 960,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'isDeleted': false,
      };
      fakeFirestore.storage['users/auth_user_del_hyd/fastingRecords/deleted_002'] = {
        'recordId': 'deleted_002',
        'fastingStartAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1, 18, 0)),
        'fastingEndAt': Timestamp.fromDate(DateTime.utc(2026, 9, 2, 10, 0)),
        'duration': 960,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'isDeleted': true,
      };

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'auth_user_del_hyd',
        email: 'delhyd@example.com',
      );

      expect(HiveService.instance.fastingRecordsBox.containsKey('active_001'), isTrue);
      expect(HiveService.instance.fastingRecordsBox.containsKey('deleted_002'), isFalse);
    });

    test('23. Reinstall recovery test: Simulating fresh install, login, Firestore hydration, and end-date verification', () async {
      // 1. Existing user in Firestore
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      fakeFirestore.storage['users/reinstall_user_777'] = {
        'uid': 'reinstall_user_777',
        'email': 'reinstall@example.com',
        'profile': {
          'name': 'Reinstalled User',
          'gender': 'male',
          'ageYears': 32,
          'heightCm': 180.0,
          'weightKg': 75.0,
          'goalWeightKg': 70.0,
          'targetBodyFat': 16.0,
          'targetWaist': 82.0,
          'targetBmi': 23.1,
          'selectedPlanId': '16-8',
          'onboardingComplete': true,
        },
      };
      fakeFirestore.storage['users/reinstall_user_777/fastingRecords/reinstall_rec_1'] = {
        'recordId': 'reinstall_rec_1',
        'fastingStartAt': Timestamp.fromDate(start.toUtc()),
        'fastingEndAt': Timestamp.fromDate(end.toUtc()),
        'duration': end.difference(start).inMinutes,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'note': 'Reinstall test record',
        'createdAt': Timestamp.fromDate(start.toUtc()),
        'updatedAt': Timestamp.fromDate(end.toUtc()),
        'isDeleted': false,
      };

      // 2. Clear all local Hive boxes (simulating fresh app install after uninstall)
      await HiveService.instance.userProfileBox.clear();
      await HiveService.instance.fastingScheduleBox.clear();
      await HiveService.instance.fastingRecordsBox.clear();
      await HiveService.instance.settingsBox.clear();

      expect(HiveService.instance.allFastingRecords.isEmpty, isTrue);
      expect(HiveService.instance.getUserProfileFor('reinstall_user_777'), isNull);

      // 3. User logs in
      fakeAuth.setUser(FakeUser('reinstall_user_777', 'reinstall@example.com'));
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'reinstall_user_777',
        email: 'reinstall@example.com',
      );

      // 4. Verify exact values restored
      final profile = HiveService.instance.getUserProfileFor('reinstall_user_777');
      expect(profile, isNotNull);
      expect(profile!.name, equals('Reinstalled User'));
      expect(profile.onboardingComplete, isTrue);

      final records = HiveService.instance.allFastingRecords;
      expect(records.length, equals(1));
      final rec = records.first;
      expect(rec.id, equals('reinstall_rec_1'));
      expect(rec.fastingStartAt, equals(start));
      expect(rec.fastingEndAt, equals(end));
      expect(rec.fastingEndAt.day, equals(3));
      expect(rec.duration.toDetailedSpelledOut, equals('17 hours 40 minutes'));
    });

    test('24. Full pipeline test: Firestore -> Hive -> Riverpod State Provider -> History Grouping', () async {
      // 1. Setup Firestore cloud record
      final start = DateTime(2026, 9, 2, 17, 0);
      final end = DateTime(2026, 9, 3, 10, 40);

      fakeFirestore.storage['users/pipeline_user_888'] = {
        'uid': 'pipeline_user_888',
        'email': 'pipeline@example.com',
        'profile': {'name': 'Pipeline User', 'onboardingComplete': true},
      };
      fakeFirestore.storage['users/pipeline_user_888/fastingRecords/pipeline_rec_1'] = {
        'recordId': 'pipeline_rec_1',
        'fastingStartAt': Timestamp.fromDate(start.toUtc()),
        'fastingEndAt': Timestamp.fromDate(end.toUtc()),
        'duration': end.difference(start).inMinutes,
        'eatingMinutes': 480,
        'planName': '16:8',
        'status': 'completed',
        'isDeleted': false,
      };

      // 2. Hydrate from Firestore into Hive
      fakeAuth.setUser(FakeUser('pipeline_user_888', 'pipeline@example.com'));
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'pipeline_user_888',
        email: 'pipeline@example.com',
      );

      final hydratedRecords = HiveService.instance.allFastingRecords;
      expect(hydratedRecords.length, equals(1));
      expect(hydratedRecords.first.id, equals('pipeline_rec_1'));

      // 3. Read through Riverpod Container
      final container = ProviderContainer();
      final providerRecords = container.read(fastingRecordsProvider);

      expect(providerRecords.length, equals(1));
      final rec = providerRecords.first;
      expect(rec.id, equals('pipeline_rec_1'));
      expect(rec.fastingStartAt, equals(start));
      expect(rec.fastingEndAt, equals(end));
      expect(rec.fastingEndAt.day, equals(3));
      expect(rec.fastingEndAt.month, equals(9));
      expect(rec.fastingEndAt.year, equals(2026));
      expect(rec.duration.toDetailedSpelledOut, equals('17 hours 40 minutes'));

      FastingEngine().dispose();
      container.dispose();
    });
  });
}

