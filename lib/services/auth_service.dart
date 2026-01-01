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

  /// Get user email if signed in
  String? get userEmail => currentUser?.email;

  /// Get user display name
  String? get userName => currentUser?.displayName;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get stable user ID for data isolation
  /// Returns Firebase UID for signed-in users, null for guests
  /// CRITICAL: This is used to scope local storage per user
  String? get userId => currentUser?.uid;

  /// Sign in with Google
  ///
  /// Returns the signed-in user or null if cancelled/failed
  /// If user was previously a guest, caller should handle data migration
  Future<User?> signInWithGoogle() async {
    try {
      print('[AuthService] Starting Google Sign-In flow...');

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        print('[AuthService] User cancelled Google Sign-In');
        return null;
      }

      print('[AuthService] Google account selected: ${googleUser.email}');
      print('[AuthService] Getting authentication tokens...');

      // Get auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print(
        '[AuthService] Got tokens - accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}',
      );

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('[AuthService] Signing in to Firebase...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      print(
        '[AuthService] Firebase sign-in successful! User: ${userCredential.user?.email}',
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('[AuthService] FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('[AuthService] Error signing in with Google: $e');
      print('[AuthService] Stack trace: $stackTrace');
      rethrow;
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

  /// Check if this is first sign-in for a user
  /// Used to determine if we need to migrate guest data
  bool isNewUser(UserCredential credential) {
    return credential.additionalUserInfo?.isNewUser ?? false;
  }
}
