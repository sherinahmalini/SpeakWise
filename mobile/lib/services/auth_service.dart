import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as all_platforms;

import 'google_oauth_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final all_platforms.GoogleSignIn _googleSignIn =
      all_platforms.GoogleSignIn(
    params: const all_platforms.GoogleSignInParams(
      clientId: GoogleOAuthConfig.clientId,
      clientSecret: GoogleOAuthConfig.clientSecret,
      redirectPort: GoogleOAuthConfig.redirectPort,
      scopes: <String>[
        'openid',
        'profile',
        'email',
      ],
    ),
  );

  // =========================================================
  // CHECK GOOGLE OAUTH CONFIGURATION
  // =========================================================

  void _checkGoogleConfiguration() {
    if (GoogleOAuthConfig.clientId.trim().isEmpty) {
      throw Exception(
        'Google Client ID is missing. '
        'Start SpeakWise with GOOGLE_CLIENT_ID configured.',
      );
    }

    if (GoogleOAuthConfig.clientSecret.trim().isEmpty) {
      throw Exception(
        'Google Client Secret is missing. '
        'Start SpeakWise with GOOGLE_CLIENT_SECRET configured.',
      );
    }
  }

  // =========================================================
  // REGISTER WITH EMAIL + PASSWORD
  // =========================================================

  Future<UserCredential?> register({
    required String fullName,
    required String matricNumber,
    required String email,
    required String password,
  }) async {
    User? createdUser;

    try {
      final String cleanFullName = fullName.trim();
      final String cleanMatricNumber = matricNumber.trim();
      final String cleanEmail = email.trim().toLowerCase();

      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Firebase created the account but no user was returned.',
        );
      }

      await createdUser.updateDisplayName(cleanFullName);

      try {
        await _firestore.collection('users').doc(createdUser.uid).set({
          'uid': createdUser.uid,
          'fullName': cleanFullName,
          'matricNumber': cleanMatricNumber,
          'email': cleanEmail,
          'authProvider': 'password',
          'emailVerified': createdUser.emailVerified,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Ignore cleanup failure.
        }

        rethrow;
      }

      if (!createdUser.emailVerified) {
        await createdUser.sendEmailVerification();
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // =========================================================
  // EMAIL/PASSWORD LOGIN
  // =========================================================

  Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    try {
      final String cleanEmail = email.trim().toLowerCase();

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      await credential.user?.reload();

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser != null) {
        await _syncVerificationStatus(refreshedUser);
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // =========================================================
  // GOOGLE SIGN-IN
  // WINDOWS / DESKTOP + SUPPORTED PLATFORMS
  // =========================================================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      _checkGoogleConfiguration();

      final all_platforms.GoogleSignInCredentials? googleCredentials =
          await _googleSignIn.signInOnline();

      if (googleCredentials == null) {
        return null;
      }

      final String? idToken = googleCredentials.idToken;
      final String accessToken = googleCredentials.accessToken;

      if ((idToken == null || idToken.isEmpty) && accessToken.isEmpty) {
        throw Exception(
          'Google Sign-In completed, but Google did not return '
          'a usable authentication token.',
        );
      }

      final OAuthCredential firebaseCredential = GoogleAuthProvider.credential(
        idToken: (idToken != null && idToken.isNotEmpty) ? idToken : null,
        accessToken: accessToken.isNotEmpty ? accessToken : null,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(firebaseCredential);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception(
          'Google Sign-In completed but Firebase did not return a user.',
        );
      }

      await user.reload();

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception(
          'Unable to refresh the Google account after sign-in.',
        );
      }

      await _createOrUpdateGoogleProfile(
        firebaseUser: refreshedUser,
      );

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // =========================================================
  // CREATE / UPDATE GOOGLE PROFILE
  // =========================================================

  Future<void> _createOrUpdateGoogleProfile({
    required User firebaseUser,
  }) async {
    final DocumentReference<Map<String, dynamic>> userReference =
        _firestore.collection('users').doc(firebaseUser.uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await userReference.get();

    final String googleName = (firebaseUser.displayName ?? '').trim();
    final String googleEmail = (firebaseUser.email ?? '').trim().toLowerCase();

    if (!snapshot.exists) {
      await userReference.set({
        'uid': firebaseUser.uid,
        'fullName': googleName.isNotEmpty ? googleName : 'SpeakWise User',
        'matricNumber': '',
        'email': googleEmail,
        'authProvider': 'google',
        'emailVerified': firebaseUser.emailVerified,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    final Map<String, dynamic> existingData =
        snapshot.data() ?? <String, dynamic>{};

    final String existingName =
        existingData['fullName']?.toString().trim() ?? '';

    await userReference.set(
      {
        'uid': firebaseUser.uid,
        'email': googleEmail,
        'authProvider': 'google',
        'emailVerified': firebaseUser.emailVerified,
        if (existingName.isEmpty && googleName.isNotEmpty)
          'fullName': googleName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // =========================================================
  // CHECK IF GOOGLE USER NEEDS MATRIC NUMBER
  // =========================================================

  Future<bool> googleUserNeedsMatricNumber() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(user.uid).get();

    if (!snapshot.exists) {
      return true;
    }

    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

    final String matricNumber = data['matricNumber']?.toString().trim() ?? '';

    return matricNumber.isEmpty;
  }

  // =========================================================
  // COMPLETE GOOGLE PROFILE
  // =========================================================

  Future<void> completeGoogleProfile({
    required String matricNumber,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user found.',
      );
    }

    final String cleanMatricNumber = matricNumber.trim();

    if (cleanMatricNumber.isEmpty) {
      throw Exception(
        'Matric number cannot be empty.',
      );
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'matricNumber': cleanMatricNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // =========================================================
  // SEND EMAIL VERIFICATION
  // =========================================================

  Future<void> sendEmailVerification() async {
    User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user found.',
      );
    }

    await user.reload();

    user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Unable to refresh the current user.',
      );
    }

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }

    await _syncVerificationStatus(user);
  }

  // =========================================================
  // CHECK EMAIL VERIFICATION
  // =========================================================

  Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await user.reload();

    user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await _syncVerificationStatus(user);

    return user.emailVerified;
  }

  // =========================================================
  // SYNC VERIFICATION STATUS
  // =========================================================

  Future<void> _syncVerificationStatus(
    User user,
  ) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'emailVerified': user.emailVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Firebase Authentication remains the source of truth.
    }
  }

  // =========================================================
  // PASSWORD RESET
  // =========================================================

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();

    await _auth.sendPasswordResetEmail(
      email: cleanEmail,
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // =========================================================
  // CURRENT USER
  // =========================================================

  User? get currentUser => _auth.currentUser;

  // =========================================================
  // AUTH STATE
  // =========================================================

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // =========================================================
  // GET USER DATA
  // =========================================================

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserData(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).get();
  }

  // =========================================================
  // GET CURRENT USER DATA
  // =========================================================

  Future<DocumentSnapshot<Map<String, dynamic>>?> getCurrentUserData() async {
    final User? user = currentUser;

    if (user == null) {
      return null;
    }

    return getUserData(user.uid);
  }

  // =========================================================
  // UPDATE USER PROFILE
  // =========================================================

  Future<void> updateUserProfile({
    required String fullName,
    required String matricNumber,
  }) async {
    final User? user = currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user found.',
      );
    }

    final String cleanFullName = fullName.trim();
    final String cleanMatricNumber = matricNumber.trim();

    if (cleanFullName.isEmpty) {
      throw Exception(
        'Full name cannot be empty.',
      );
    }

    if (cleanMatricNumber.isEmpty) {
      throw Exception(
        'Matric number cannot be empty.',
      );
    }

    await _firestore.collection('users').doc(user.uid).update({
      'fullName': cleanFullName,
      'matricNumber': cleanMatricNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await user.updateDisplayName(cleanFullName);
  }

  // =========================================================
  // CHECK IF LOGGED IN
  // =========================================================

  bool get isLoggedIn {
    return _auth.currentUser != null;
  }
}
