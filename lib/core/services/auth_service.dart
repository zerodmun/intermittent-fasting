import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';

class DeviceAlreadyLinkedException implements Exception {
  final String message;
  DeviceAlreadyLinkedException([this.message = 'This account is already linked to another device.']);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _customAuth;
  FirebaseFirestore? _customFirestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  void setMockInstances({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
    _customAuth = auth;
    _customFirestore = firestore;
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    try {
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Diagnostic query to identify all users associated with [deviceId] in Firestore.
  /// Reports duplicate bindings without deleting any user documents or user data.
  Future<List<String>> findDuplicateDeviceBindings(String deviceId) async {
    final List<String> userIds = [];
    try {
      final query = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get()
          .timeout(const Duration(seconds: 5));

      for (final doc in query.docs) {
        userIds.add(doc.id);
      }

      if (userIds.length > 1) {
        LoggerService.w('[DEVICE-DIAG] Duplicate device bindings found for device $deviceId: $userIds');
      } else {
        LoggerService.i('[DEVICE-DIAG] Device $deviceId bound to active user(s): $userIds');
      }
    } catch (e) {
      LoggerService.w('[DEVICE-DIAG] Error querying duplicate device bindings: $e');
    }
    return userIds;
  }

  /// Transfers active device binding to [uid] and unlinks previous active account bindings for [deviceId].
  /// Does NOT delete old user accounts or account history data.
  Future<void> _transferDeviceBinding({
    required String uid,
    required String deviceId,
  }) async {
    final authUser = currentUser;
    if (authUser == null || authUser.uid != uid) {
      LoggerService.w(
        '[FIRESTORE-SECURITY-BLOCK] reason: unauthenticated device transfer, requestedUid: $uid, authenticatedUid: ${authUser?.uid}, source: AuthService._transferDeviceBinding',
      );
      return;
    }

    LoggerService.d('[FIRESTORE-USER-WRITE] uid: $uid, authUid: ${authUser.uid}, source: AuthService._transferDeviceBinding, operation: transfer device binding');

    try {
      final query = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get()
          .timeout(const Duration(seconds: 5));

      for (final doc in query.docs) {
        if (doc.id != uid) {
          await doc.reference.set({
            'deviceId': FieldValue.delete(),
            'accountStatus': 'unlinked',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final oldDeviceDoc = doc.reference.collection('devices').doc(deviceId);
          await oldDeviceDoc.set({
            'status': 'unlinked',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.set({
        'uid': uid,
        'deviceId': deviceId,
        'accountStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final deviceDocRef = userDocRef.collection('devices').doc(deviceId);
      await deviceDocRef.set({
        'deviceId': deviceId,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      LoggerService.w('AuthService: Device binding transfer warning: $e');
    }
  }

  /// Unbinds active device assignment from user doc upon sign out without deleting account
  Future<void> _unbindDeviceFromUser({
    required String uid,
    required String deviceId,
  }) async {
    final authUser = currentUser;
    if (authUser == null || authUser.uid != uid) {
      LoggerService.w(
        '[FIRESTORE-SECURITY-BLOCK] reason: unauthenticated device unbind, requestedUid: $uid, authenticatedUid: ${authUser?.uid}, source: AuthService._unbindDeviceFromUser',
      );
      return;
    }

    LoggerService.d('[FIRESTORE-USER-WRITE] uid: $uid, authUid: ${authUser.uid}, source: AuthService._unbindDeviceFromUser, operation: unbind device');

    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.set({
        'deviceId': FieldValue.delete(),
        'accountStatus': 'unlinked',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final deviceDocRef = userDocRef.collection('devices').doc(deviceId);
      await deviceDocRef.set({
        'status': 'unlinked',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      LoggerService.w('AuthService: Unbind device warning: $e');
    }
  }

  /// Signs up with email and password, creating the account device binding in users/{uid}
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final deviceId = FcmService.instance.getOrCreateDeviceId();
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = userCredential.user;
    if (user != null) {
      LoggerService.d('[FIRESTORE-USER-WRITE] uid: ${user.uid}, authUid: ${user.uid}, source: AuthService.signUpWithEmail, operation: create user document');
      await _transferDeviceBinding(uid: user.uid, deviceId: deviceId);

      final userDocRef = _firestore.collection('users').doc(user.uid);
      await userDocRef.set({
        'uid': user.uid,
        'email': user.email,
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
      }, SetOptions(merge: true));


      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: user.uid,
        email: user.email ?? email,
      );

      await _resyncServicesAfterAuthChange();
    }
    return userCredential;
  }

  /// Signs in with email and password, validating stored deviceId == currentDeviceId
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final deviceId = FcmService.instance.getOrCreateDeviceId();
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = userCredential.user;

    if (user != null) {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final docSnap = await userDocRef.get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final storedDeviceId = data?['deviceId'] as String?;

        if (storedDeviceId != null && storedDeviceId != deviceId) {
          // Account already bound to a DIFFERENT physical device
          await _auth.signOut();
          throw DeviceAlreadyLinkedException();
        }
      }

      await _transferDeviceBinding(uid: user.uid, deviceId: deviceId);

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: user.uid,
        email: user.email ?? email,
      );

      await _resyncServicesAfterAuthChange();
    }
    return userCredential;
  }

  /// Sends a password reset email to the specified email address
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Verifies password reset code and returns the associated email address
  Future<String> verifyPasswordResetCode({required String code}) async {
    return await _auth.verifyPasswordResetCode(code.trim());
  }

  /// Confirms password reset with code and updates password in Firebase Auth
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await _auth.confirmPasswordReset(code: code.trim(), newPassword: newPassword);
  }


  /// Signs out of Firebase Auth while preserving all local Hive data and device identity on device
  Future<void> signOut() async {
    final user = currentUser;
    final deviceId = FcmService.instance.getOrCreateDeviceId();

    if (user != null) {
      await _unbindDeviceFromUser(uid: user.uid, deviceId: deviceId);
    }

    try {
      await _auth.signOut();
    } catch (e) {
      LoggerService.w('AuthService: Firebase signout warning: $e');
    }

    // Reset local migration bound session markers without wiping local Hive data or deviceId
    await HiveService.instance.setSetting('bound_firebase_uid', null);
    await HiveService.instance.setSetting('migration_status', 'legacy_local_user');

    // Local notifications only: do NOT run cloud synchronization when signed out
    try {
      NotificationService.instance.scheduleReminderNotifications('Auth Sign Out');
    } catch (_) {}
  }

  /// Helper to trigger notification schedule update and FCM re-registration after auth state changes
  Future<void> _resyncServicesAfterAuthChange() async {
    try {
      final user = currentUser;
      if (user != null) {
        final schedule = HiveService.instance.fastingSchedule;
        await NotificationSyncService.instance.updateSchedule(
          schedule: schedule,
          incrementVersion: true,
        );
        await FcmService.instance.reRegisterToken();
      } else {
        NotificationService.instance.scheduleReminderNotifications('Auth State Change (Logged Out)');
      }
    } catch (e) {
      LoggerService.w('AuthService: Error re-syncing services after auth change: $e');
    }
  }
}

