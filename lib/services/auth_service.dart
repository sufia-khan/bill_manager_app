import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication Service
/// Handles Google Sign-In and Guest mode
///
/// Key features:
/// - Google Sign-In integration
/// - Guest mode (local-only data)
/// - Guest-to-Google migration support
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Current Firebase user (null if guest or not signed in)
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in with Google
  bool get isSignedIn => currentUser != null;

  /// Check if user is in guest mode
  bool get isGuest => currentUser == null;

  /// Get user email if signed in
  String? get userEmail => currentUser?.email;

  /// Get user display name
  String? get userName => currentUser?.displayName;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  ///
  /// Returns the signed-in user or null if cancelled/failed
  /// If user was previously a guest, caller should handle data migration
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Get auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Continue as guest (no-op, just returns true)
  /// Guest data is stored locally only
  Future<bool> continueAsGuest() async {
    // Make sure we're signed out of any previous session
    if (isSignedIn) {
      await signOut();
    }
    return true;
  }

  /// Check if this is first sign-in for a user
  /// Used to determine if we need to migrate guest data
  bool isNewUser(UserCredential credential) {
    return credential.additionalUserInfo?.isNewUser ?? false;
  }
}
