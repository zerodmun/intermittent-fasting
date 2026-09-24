// ignore_for_file: subtype_of_sealed_class
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/weight/presentation/providers/weight_providers.dart';
import 'package:fast_flow/features/body_composition/presentation/providers/body_comp_providers.dart';

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

  @override
  Future<void> signOut() async {
    _user = null;
  }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;

  UserProfile createSampleProfile({
    required String name,
    double weightKg = 75.0,
    double goalWeightKg = 68.0,
  }) {
    return UserProfile(
      name: name,
      gender: 'male',
      ageYears: 30,
      heightCm: 175.0,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      targetBodyFat: 15.0,
      targetWaist: 80.0,
      targetBmi: 22.0,
      selectedPlanId: '16-8',
      onboardingComplete: true,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('weight_logs_firestore_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth();
    AuthService.instance.setMockInstances(auth: fakeAuth, firestore: fakeFirestore);
    HiveService.instance.setMockFirestore(fakeFirestore);
    UserDataMigrationService.instance.setMockFirestore(fakeFirestore);
    FcmService.instance.resetMemoryCache();

    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
    await HiveService.instance.weightEntriesBox.clear();
    await HiveService.instance.settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Weight Logs Firestore Persistence & Synchronization Suite', () {
    test('Scenario 1: Add a new Weight Log while logged in -> saved to Firestore and local Hive', () async {
      const uid = 'user_weight_sync_001';
      fakeAuth.setUser(FakeUser(uid, 'user1@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      await HiveService.instance.setSetting('migration_status', 'completed');

      final entry = WeightEntry(
        id: '${uid}_entry_001',
        weightKg: 78.5,
        date: DateTime(2026, 9, 1, 8, 30),
        bodyFatPercentage: 18.2,
        waistCm: 84.0,
        note: 'Morning weigh-in',
      );

      await HiveService.instance.saveWeightEntry(entry);

      // Verify stored in local Hive
      final localEntries = HiveService.instance.allWeightEntries;
      expect(localEntries.length, equals(1));
      expect(localEntries.first.id, equals('${uid}_entry_001'));
      expect(localEntries.first.weightKg, equals(78.5));
      expect(localEntries.first.note, equals('Morning weigh-in'));

      // Verify synced to Firestore
      final cloudDoc = fakeFirestore.storage['users/$uid/weightLogs/${entry.id}'];
      expect(cloudDoc, isNotNull);
      expect(cloudDoc!['weightKg'], equals(78.5));
      expect(cloudDoc['bodyFatPercentage'], equals(18.2));
      expect(cloudDoc['waistCm'], equals(84.0));
      expect(cloudDoc['note'], equals('Morning weigh-in'));
      expect(cloudDoc['isDeleted'], isFalse);
    });

    test('Scenario 2: Close and reopen the app -> Weight Log is still displayed from local cache', () async {
      const uid = 'user_reopen_002';
      fakeAuth.setUser(FakeUser(uid, 'reopen@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final entry = WeightEntry(
        id: '${uid}_entry_reopen',
        weightKg: 74.2,
        date: DateTime(2026, 9, 2, 9, 0),
        bodyFatPercentage: 17.0,
      );
      await HiveService.instance.saveWeightEntry(entry);

      // Simulate app reopen by reading via fresh ProviderContainer
      final container = ProviderContainer();
      final loadedEntries = container.read(weightProvider);

      expect(loadedEntries.length, equals(1));
      expect(loadedEntries.first.weightKg, equals(74.2));
      container.dispose();
    });

    test('Scenario 3: Log out and log back in with same account -> Weight Logs remain available', () async {
      const uid = 'user_logout_relogin_003';
      fakeAuth.setUser(FakeUser(uid, 'logout_relogin@example.com'));
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'John Doe'), uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final entry = WeightEntry(
        id: '${uid}_entry_persistent',
        weightKg: 82.0,
        date: DateTime(2026, 8, 20),
      );
      await HiveService.instance.saveWeightEntry(entry);

      // Perform logout
      await AuthService.instance.signOut();
      expect(AuthService.instance.currentUser, isNull);

      // Log back in
      fakeAuth.setUser(FakeUser(uid, 'logout_relogin@example.com'));
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: uid,
        email: 'logout_relogin@example.com',
      );

      final entriesAfterRelogin = HiveService.instance.allWeightEntries;
      expect(entriesAfterRelogin.length, equals(1));
      expect(entriesAfterRelogin.first.weightKg, equals(82.0));
    });

    test('Scenario 4: Reinstall simulation (empty local storage) -> Log in -> All Weight Logs restored from Firestore', () async {
      const uid = 'user_reinstall_004';

      // 1. Seed Firestore with historical weight logs
      final userDocRef = fakeFirestore.collection('users').doc(uid);
      await userDocRef.set({
        'uid': uid,
        'email': 'reinstall@example.com',
        'profile': {
          'name': 'Cloud User',
          'gender': 'female',
          'ageYears': 27,
          'heightCm': 165.0,
          'weightKg': 60.0,
          'goalWeightKg': 55.0,
          'onboardingComplete': true,
        },
      });

      for (int i = 1; i <= 5; i++) {
        final logId = '${uid}_history_$i';
        await userDocRef.collection('weightLogs').doc(logId).set({
          'id': logId,
          'weightKg': 65.0 - (i * 0.5),
          'date': DateTime(2026, 8, i).toUtc().toIso8601String(),
          'bodyFatPercentage': 24.0 - (i * 0.2),
          'waistCm': 75.0 - i,
          'note': 'Log $i',
          'createdAt': DateTime(2026, 8, i).toUtc().toIso8601String(),
          'updatedAt': DateTime(2026, 8, i).toUtc().toIso8601String(),
          'isDeleted': false,
          'syncStatus': 'synced',
        });
      }

      // 2. Ensure local storage is empty (clean install)
      await HiveService.instance.weightEntriesBox.clear();
      await HiveService.instance.userProfileBox.clear();
      expect(HiveService.instance.weightEntriesBox.isEmpty, isTrue);

      // 3. Authenticate and run post-login hydration
      fakeAuth.setUser(FakeUser(uid, 'reinstall@example.com'));
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: uid,
        email: 'reinstall@example.com',
      );

      // 4. Verify all 5 weight logs are restored into Hive
      final restoredEntries = HiveService.instance.allWeightEntries;
      expect(restoredEntries.length, equals(5));
      expect(restoredEntries.first.weightKg, equals(62.5)); // latest (i=5)
      expect(restoredEntries.last.weightKg, equals(64.5)); // oldest (i=1)
      expect(restoredEntries.first.bodyFatPercentage, equals(23.0));
    });

    test('Scenario 5: Multi-account isolation -> User A and User B cannot see each other\'s Weight Logs', () async {
      const uidA = 'user_A_isolated';
      const uidB = 'user_B_isolated';

      // Setup User A
      fakeAuth.setUser(FakeUser(uidA, 'a@example.com'));
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'User A'), uidA);
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      await HiveService.instance.saveWeightEntry(
        WeightEntry(id: '${uidA}_log1', weightKg: 70.0, date: DateTime(2026, 9, 1)),
      );

      // Setup User B
      fakeAuth.setUser(FakeUser(uidB, 'b@example.com'));
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'User B'), uidB);
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      await HiveService.instance.saveWeightEntry(
        WeightEntry(id: '${uidB}_log1', weightKg: 90.0, date: DateTime(2026, 9, 1)),
      );

      // Active User B
      expect(HiveService.instance.allWeightEntries.length, equals(1));
      expect(HiveService.instance.allWeightEntries.first.weightKg, equals(90.0));
      expect(HiveService.instance.allWeightEntries.first.id, equals('${uidB}_log1'));

      // Switch to User A
      fakeAuth.setUser(FakeUser(uidA, 'a@example.com'));
      await UserDataMigrationService.instance.switchAccount(uidA);
      expect(HiveService.instance.allWeightEntries.length, equals(1));
      expect(HiveService.instance.allWeightEntries.first.weightKg, equals(70.0));
      expect(HiveService.instance.allWeightEntries.first.id, equals('${uidA}_log1'));

      // Switch back to User B
      fakeAuth.setUser(FakeUser(uidB, 'b@example.com'));
      await UserDataMigrationService.instance.switchAccount(uidB);
      expect(HiveService.instance.allWeightEntries.length, equals(1));
      expect(HiveService.instance.allWeightEntries.first.weightKg, equals(90.0));
    });

    test('Scenario 6: Offline creation, edit, deletion, and online sync', () async {
      const uid = 'user_offline_sync_006';

      // 1. Log in while connected
      fakeAuth.setUser(FakeUser(uid, 'offline@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      await HiveService.instance.setSetting('migration_status', 'completed');

      // 2. Go "offline" by setting null mock firestore in HiveService
      HiveService.instance.setMockFirestore(null);

      final offlineEntry = WeightEntry(
        id: '${uid}_offline_001',
        weightKg: 80.0,
        date: DateTime(2026, 9, 5),
        note: 'Logged offline',
      );
      await HiveService.instance.saveWeightEntry(offlineEntry);

      // Verify saved in local Hive
      expect(HiveService.instance.allWeightEntries.length, equals(1));
      expect(fakeFirestore.storage['users/$uid/weightLogs/${offlineEntry.id}'], isNull);

      // 3. Reconnect to Firestore and run sync via UserDataMigrationService
      HiveService.instance.setMockFirestore(fakeFirestore);
      UserDataMigrationService.instance.setMockFirestore(fakeFirestore);

      // Ensure user doc exists in Firestore for hydration check
      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': 'offline@example.com',
      });

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: uid,
        email: 'offline@example.com',
      );

      // Verify synced up to Firestore
      final syncedCloudDoc = fakeFirestore.storage['users/$uid/weightLogs/${offlineEntry.id}'];
      expect(syncedCloudDoc, isNotNull);
      expect(syncedCloudDoc!['weightKg'], equals(80.0));
      expect(syncedCloudDoc['note'], equals('Logged offline'));

      // 4. Test delete operation
      await HiveService.instance.deleteWeightEntry(offlineEntry.id);
      expect(HiveService.instance.allWeightEntries.isEmpty, isTrue);

      final deletedCloudDoc = fakeFirestore.storage['users/$uid/weightLogs/${offlineEntry.id}'];
      expect(deletedCloudDoc, isNotNull);
      expect(deletedCloudDoc!['isDeleted'], isTrue);
    });

    test('Scenario 7: Migrate existing local/unclaimed Weight Logs to Firestore upon first sign up', () async {
      // 1. Guest user logs weight while unauthenticated
      await HiveService.instance.setSetting('bound_firebase_uid', null);
      await HiveService.instance.setSetting('legacy_data_claimed', false);

      final localGuestProfile = createSampleProfile(name: 'Guest User', weightKg: 77.0);
      await HiveService.instance.userProfileBox.put('profile', localGuestProfile);

      for (int i = 1; i <= 3; i++) {
        final guestEntry = WeightEntry(
          id: 'guest_weight_$i',
          weightKg: 77.0 - (i * 0.5),
          date: DateTime(2026, 9, i),
        );
        await HiveService.instance.saveWeightEntry(guestEntry);
      }

      expect(HiveService.instance.hasUnclaimedLocalUserData(), isTrue);

      // 2. User creates an account (brand new Firebase user)
      const newUid = 'brand_new_firebase_user_007';
      fakeAuth.setUser(FakeUser(newUid, 'newuser@example.com'));

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: newUid,
        email: 'newuser@example.com',
      );

      // 3. Verify all 3 local entries are uploaded to new user's Firestore collection
      for (int i = 1; i <= 3; i++) {
        final cloudLog = fakeFirestore.storage['users/$newUid/weightLogs/guest_weight_$i'];
        expect(cloudLog, isNotNull);
        expect(cloudLog!['weightKg'], equals(77.0 - (i * 0.5)));
      }

      // 4. Verify local entries are claimed and accessible by new user
      expect(HiveService.instance.allWeightEntries.length, equals(3));
    });

    test('Scenario 8: Last-Write-Wins conflict resolution handles newer local updates correctly', () async {
      const uid = 'user_lww_008';
      const logId = '${uid}_lww_log';

      // 1. Seed Firestore with older version (updated 2 days ago)
      final olderDate = DateTime.now().subtract(const Duration(days: 2));
      final userDocRef = fakeFirestore.collection('users').doc(uid);
      await userDocRef.set({'uid': uid, 'email': 'lww@example.com'});
      await userDocRef.collection('weightLogs').doc(logId).set({
        'id': logId,
        'weightKg': 75.0,
        'date': olderDate.toUtc().toIso8601String(),
        'createdAt': olderDate.toUtc().toIso8601String(),
        'updatedAt': olderDate.toUtc().toIso8601String(),
        'note': 'Older cloud note',
        'isDeleted': false,
      });

      // 2. Local Hive has a newer edited version (updated 1 hour ago)
      final newerDate = DateTime.now().subtract(const Duration(hours: 1));
      final localEntry = WeightEntry(
        id: logId,
        weightKg: 73.5,
        date: olderDate,
        createdAt: olderDate,
        updatedAt: newerDate,
        note: 'Newer local edit',
      );
      await HiveService.instance.weightEntriesBox.put(logId, localEntry);

      // 3. Run post login migration
      fakeAuth.setUser(FakeUser(uid, 'lww@example.com'));
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: uid,
        email: 'lww@example.com',
      );

      // 4. Verify local version was preserved and pushed to Firestore
      final active = HiveService.instance.weightEntriesBox.get(logId);
      expect(active?.weightKg, equals(73.5));
      expect(active?.note, equals('Newer local edit'));

      final cloudDoc = fakeFirestore.storage['users/$uid/weightLogs/$logId'];
      expect(cloudDoc!['weightKg'], equals(73.5));
      expect(cloudDoc['note'], equals('Newer local edit'));
    });

    test('Scenario 9: Body Composition providers recalculate reactively when Weight Logs update', () async {
      const uid = 'user_body_comp_009';
      fakeAuth.setUser(FakeUser(uid, 'comp@example.com'));
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final profile = createSampleProfile(name: 'Athlete User', weightKg: 80.0, goalWeightKg: 72.0);
      await HiveService.instance.saveUserProfile(profile, uid);

      final container = ProviderContainer();

      // Initially no entries
      expect(container.read(weightProvider).isEmpty, isTrue);
      expect(container.read(currentWeightProvider), isNull);

      // Add first entry
      final entry1 = WeightEntry(
        id: '${uid}_comp_1',
        weightKg: 80.0,
        date: DateTime(2026, 9, 1),
        bodyFatPercentage: 20.0,
        waistCm: 85.0,
      );
      await HiveService.instance.saveWeightEntry(entry1);

      // Small tick for box watcher
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(currentWeightProvider)?.weightKg, equals(80.0));

      // Add second entry (latest)
      final entry2 = WeightEntry(
        id: '${uid}_comp_2',
        weightKg: 78.0,
        date: DateTime(2026, 9, 5),
        bodyFatPercentage: 18.5,
        waistCm: 83.0,
      );
      await HiveService.instance.saveWeightEntry(entry2);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(currentWeightProvider)?.weightKg, equals(78.0));
      expect(container.read(bodyCompEntriesProvider).length, equals(2));

      container.dispose();
    });

    test('Scenario 10: Multi-account lifecycle with realistic alphanumeric Firebase UIDs', () async {
      const uidAlice = 'Xk98Pq12Z7';
      const uidBob = 'Lw23Rt78V1';

      // 1. Alice logs in and creates logs
      fakeAuth.setUser(FakeUser(uidAlice, 'alice@example.com'));
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'Alice'), uidAlice);
      await HiveService.instance.setSetting('bound_firebase_uid', uidAlice);
      await HiveService.instance.registerKnownAccount(uid: uidAlice, email: 'alice@example.com');

      final aliceLog1 = WeightEntry(id: '${uidAlice}_log_1', weightKg: 62.0, date: DateTime(2026, 9, 1));
      final aliceLog2 = WeightEntry(id: '${uidAlice}_log_2', weightKg: 61.5, date: DateTime(2026, 9, 2));
      await HiveService.instance.saveWeightEntry(aliceLog1);
      await HiveService.instance.saveWeightEntry(aliceLog2);

      expect(HiveService.instance.allWeightEntries.length, equals(2));

      // 2. Alice logs out
      await AuthService.instance.signOut();
      expect(AuthService.instance.currentUser, isNull);

      // 3. Bob logs in
      fakeAuth.setUser(FakeUser(uidBob, 'bob@example.com'));
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'Bob'), uidBob);
      await HiveService.instance.setSetting('bound_firebase_uid', uidBob);
      await HiveService.instance.registerKnownAccount(uid: uidBob, email: 'bob@example.com');

      // 4. Bob must see zero logs from Alice
      expect(HiveService.instance.allWeightEntries.isEmpty, isTrue);

      // 5. Bob creates his own logs
      final bobLog1 = WeightEntry(id: '${uidBob}_log_1', weightKg: 85.0, date: DateTime(2026, 9, 3));
      await HiveService.instance.saveWeightEntry(bobLog1);

      expect(HiveService.instance.allWeightEntries.length, equals(1));
      expect(HiveService.instance.allWeightEntries.first.weightKg, equals(85.0));

      // 6. Switch back to Alice
      fakeAuth.setUser(FakeUser(uidAlice, 'alice@example.com'));
      await UserDataMigrationService.instance.switchAccount(uidAlice);

      // 7. Alice must see only her 2 logs, never Bob's
      final aliceEntries = HiveService.instance.allWeightEntries;
      expect(aliceEntries.length, equals(2));
      expect(aliceEntries.any((e) => e.id.contains(uidBob)), isFalse);
      expect(aliceEntries.map((e) => e.weightKg).toList(), containsAll([62.0, 61.5]));
    });

    test('Scenario 11: Offline deletion does NOT resurrect during cloud hydration and propagates to Firestore', () async {
      const uid = 'user_offline_del_011';
      const logId = '${uid}_del_test';

      // 1. Seed Firestore with a weight log
      final userDocRef = fakeFirestore.collection('users').doc(uid);
      await userDocRef.set({'uid': uid, 'email': 'del@example.com'});
      await userDocRef.collection('weightLogs').doc(logId).set({
        'id': logId,
        'weightKg': 75.0,
        'date': DateTime(2026, 9, 1).toUtc().toIso8601String(),
        'createdAt': DateTime(2026, 9, 1).toUtc().toIso8601String(),
        'updatedAt': DateTime(2026, 9, 1).toUtc().toIso8601String(),
        'isDeleted': false,
      });

      // 2. User was offline and deleted it locally
      HiveService.instance.setMockFirestore(null);
      await HiveService.instance.weightEntriesBox.put(
        logId,
        WeightEntry(id: logId, weightKg: 75.0, date: DateTime(2026, 9, 1)),
      );
      await HiveService.instance.deleteWeightEntry(logId);

      expect(HiveService.instance.weightEntriesBox.get(logId), isNull);
      expect(HiveService.instance.allWeightEntries.isEmpty, isTrue);

      // 3. User reconnects and runs hydration
      HiveService.instance.setMockFirestore(fakeFirestore);
      UserDataMigrationService.instance.setMockFirestore(fakeFirestore);
      fakeAuth.setUser(FakeUser(uid, 'del@example.com'));

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: uid,
        email: 'del@example.com',
      );

      // 4. Verify record was NOT resurrected in Hive
      expect(HiveService.instance.allWeightEntries.isEmpty, isTrue);

      // 5. Verify soft delete was pushed to Firestore
      final cloudDoc = fakeFirestore.storage['users/$uid/weightLogs/$logId'];
      expect(cloudDoc, isNotNull);
      expect(cloudDoc!['isDeleted'], isTrue);
    });

    test('Scenario 12: Idempotent migration and rapid multiple syncs do not duplicate records', () async {
      const uid = 'user_idempotent_012';
      fakeAuth.setUser(FakeUser(uid, 'idempotent@example.com'));

      final userDocRef = fakeFirestore.collection('users').doc(uid);
      await userDocRef.set({'uid': uid, 'email': 'idempotent@example.com'});

      for (int i = 1; i <= 3; i++) {
        final logId = '${uid}_stable_$i';
        await userDocRef.collection('weightLogs').doc(logId).set({
          'id': logId,
          'weightKg': 70.0 + i,
          'date': DateTime(2026, 9, i).toUtc().toIso8601String(),
          'createdAt': DateTime(2026, 9, i).toUtc().toIso8601String(),
          'updatedAt': DateTime(2026, 9, i).toUtc().toIso8601String(),
          'isDeleted': false,
        });
      }

      // Run migration 3 times in a row
      await UserDataMigrationService.instance.processPostLoginMigration(uid: uid, email: 'idempotent@example.com');
      await HiveService.instance.setSetting('migration_status', 'migration_pending');
      await UserDataMigrationService.instance.processPostLoginMigration(uid: uid, email: 'idempotent@example.com');
      await HiveService.instance.setSetting('migration_status', 'migration_pending');
      await UserDataMigrationService.instance.processPostLoginMigration(uid: uid, email: 'idempotent@example.com');

      // Verify exactly 3 entries in Hive and Firestore without duplication
      final hiveEntries = HiveService.instance.allWeightEntries;
      expect(hiveEntries.length, equals(3));

      final remoteDocs = fakeFirestore.storage.keys.where((k) => k.startsWith('users/$uid/weightLogs/')).toList();
      expect(remoteDocs.length, equals(3));
    });
  });
}
