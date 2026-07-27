import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/app_user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<User?> authStateChanges();
  Future<AppUserModel> signInWithEmail({required String email, required String password});
  Future<AppUserModel> signUpWithEmail({required String email, required String password, required String displayName});
  Future<AppUserModel> signInWithGoogle();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> signOut();

  /// Re-authenticates the current Firebase user via Google Sign-In.
  /// Used by flows that require recent authentication (e.g.
  /// `delete()`). Returns a fresh [AuthCredential].
  Future<AuthCredential> reauthenticateWithGoogle();

  /// Permanently deletes the current user's account.
  ///
  /// The caller MUST ensure the user has been re-authenticated
  /// recently (e.g. by calling [reauthenticateWithGoogle]) before
  /// invoking this — otherwise Firebase will throw
  /// `requires-recent-login`.
  ///
  /// Side effects in Firestore (best-effort, wrapped in try/catch
  /// internally and logged):
  ///   1. Look up the user's `coupleId` on `users/{uid}`.
  ///   2. If `coupleId` is set, read the `couples/{coupleId}` doc
  ///      to find the partner UID (the other of `user1Id`/`user2Id`)
  ///      and clear that partner's `coupleId` so they are returned
  ///      to a single/unpaired state.
  ///   3. Delete the `users/{uid}` document.
  ///   4. Call `FirebaseAuth.instance.currentUser!.delete()`.
  Future<void> deleteAccount();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _firestore = firestore;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<AppUserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final coupleId = await _fetchCoupleId(user.uid);
      // Backfill displayName/photoUrl/email for accounts created before this fix
      await _upsertUserProfile(user.uid, email: user.email, displayName: user.displayName, photoUrl: user.photoURL);
      return AppUserModel.fromFirebaseUser(user, coupleId: coupleId);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign-in failed');
    }
  }

  @override
  Future<AppUserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName);

      final userDoc = _firestore.doc(FirestorePaths.user(user.uid));
      final model = AppUserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        photoUrl: null,
        coupleId: null,
      );
      await userDoc.set(model.toFirestore()
        ..['createdAt'] = FieldValue.serverTimestamp());
      // Also update Firebase Auth display name so it's available immediately
      await user.updateDisplayName(displayName);
      await _upsertUserProfile(user.uid, email: email, displayName: displayName, photoUrl: null);

      return model;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign-up failed');
    }
  }

  @override
  Future<AppUserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final credentialResult = await _firebaseAuth.signInWithCredential(credential);
      final user = credentialResult.user!;

      final coupleId = await _fetchCoupleId(user.uid);

      // If this is a new user (no Firestore doc), create one
      final userDoc = _firestore.doc(FirestorePaths.user(user.uid));
      final existing = await userDoc.get();
      if (!existing.exists) {
        final model = AppUserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          coupleId: null,
        );
        await userDoc.set(model.toFirestore()
          ..['createdAt'] = FieldValue.serverTimestamp());
        return model;
      }

      return AppUserModel.fromFirebaseUser(user, coupleId: coupleId);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('No signed-in user');
    }
    // Defensive: only email/password accounts can change a password.
    // (Google sign-in accounts do not have an app-managed password.)
    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');
    if (!hasPasswordProvider) {
      throw AuthException(
        'This account uses Google sign-in. Password cannot be changed here.',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      // Translate the most common codes to messages that don't
      // expose Firebase internals to the end user. We use the
      // translation keys so the messages respect the user's
      // current app language (easy_localization's `tr()` does
      // not require a BuildContext).
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          throw AuthException('changePassword.errors.wrongCurrent'.tr());
        case 'weak-password':
          throw AuthException('changePassword.errors.weak'.tr());
        case 'requires-recent-login':
          throw AuthException('changePassword.errors.reauth'.tr());
        case 'too-many-requests':
          throw AuthException('changePassword.errors.tooMany'.tr());
        case 'user-disabled':
          throw AuthException('changePassword.errors.userDisabled'.tr());
        case 'user-not-found':
          throw AuthException('changePassword.errors.userNotFound'.tr());
        default:
          throw AuthException(
              e.message ?? 'changePassword.errors.generic'.tr());
      }
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<AuthCredential> reauthenticateWithGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('No signed-in user');
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google sign-in was cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Re-authentication failed');
    }
    return credential;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('No signed-in user');
    }
    final myUid = user.uid;

    // ── Firestore: partner cleanup + own user doc — wrapped in a
    //    transaction so both writes succeed or both fail atomically.
    //    Couples/shared subcollections are intentionally left intact
    //    so the partner keeps access to them.
    // ─────────────────────────────────────────────────────────────
    try {
      await _firestore.runTransaction((tx) async {
        // (a) Clear partner's coupleId so they return to single state.
        final myDocSnap = await tx.get(_firestore.doc(FirestorePaths.user(myUid)));
        if (!myDocSnap.exists) return; // already gone — nothing to clean up

        final coupleId = myDocSnap.data()?['coupleId'] as String?;
        if (coupleId != null && coupleId.isNotEmpty) {
          final coupleSnap =
              await tx.get(_firestore.doc(FirestorePaths.couple(coupleId)));
          if (coupleSnap.exists) {
            final cData = coupleSnap.data() ?? <String, dynamic>{};
            final user1Id = cData['user1Id'] as String?;
            final user2Id = cData['user2Id'] as String?;
            final partnerUid =
                (user1Id == myUid)
                    ? user2Id
                    : (user2Id == myUid ? user1Id : null);
            if (partnerUid != null && partnerUid.isNotEmpty) {
              tx.update(
                _firestore.doc(FirestorePaths.user(partnerUid)),
                {'coupleId': null},
              );
            }
          }
        }

        // (b) Delete own users/{myUid} document.
        tx.delete(_firestore.doc(FirestorePaths.user(myUid)));
        // (c) Shared couple subcollections (streaks, pets, moods, memories,
        //     jars, etc.) are intentionally NOT deleted — partner keeps them.
      });
    } on FirebaseException catch (e, st) {
      debugPrint('[DELETE_ACCOUNT_ERR] Firestore transaction failed: '
          'code=${e.code} message=${e.message}');
      debugPrint('[DELETE_ACCOUNT_ERR] stacktrace: $st');
      throw AuthException(e.message ?? 'Database cleanup failed');
    } catch (e, st) {
      debugPrint('[DELETE_ACCOUNT_ERR] Unexpected error during Firestore '
          'transaction: $e');
      debugPrint('[DELETE_ACCOUNT_ERR] stacktrace: $st');
      throw AuthException('Database cleanup failed');
    }

    // ── Firebase Auth: permanently delete the account.
    //    Caller MUST have called reauthenticateWithGoogle() first,
    //    otherwise Firebase throws `requires-recent-login`.
    // ─────────────────────────────────────────────────────────────
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Could not delete account');
    }
  }

  /// Writes displayName/photoUrl/email to Firestore with merge:true so existing
  /// fields (e.g. coupleId) are never overwritten.
  Future<void> _upsertUserProfile(
    String uid, {
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) async {
    await _firestore.doc(FirestorePaths.user(uid)).set(
      {
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> _fetchCoupleId(String uid) async {
    try {
      final doc = await _firestore.doc(FirestorePaths.user(uid)).get();
      if (doc.exists) {
        return doc.data()?['coupleId'] as String?;
      }
    } catch (_) {
      // ignore — return null on error
    }
    return null;
  }
}
