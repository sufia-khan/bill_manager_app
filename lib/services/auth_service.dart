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
  /// [onAccountSelected] is called after the user selects an account but before Firebase auth.
  Future<User?> signInWithGoogle({Function? onAccountSelected}) async {
    try {
      // Force account picker by signing out first (clears cached account)
      try {
        await _googleSignIn.signOut();
      } catch (e) {}

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // User selected an account, notify caller
      if (onAccountSelected != null) {
        onAccountSelected();
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
    } on FirebaseAuthException {
      // FirebaseAuthException - rethrow to caller
      rethrow;
    } catch (_) {
      // Error signing in with Google
      rethrow;
    }
  }

  /// Re-authenticate user with Google
  /// Required before sensitive operations like account deletion
  /// Returns true if re-authentication was successful
  Future<bool> reauthenticateWithGoogle() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Get fresh Google credentials
      // First disconnect to ensure we get fresh credentials
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Ignore sign-out errors
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Re-authenticate with Firebase
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('[AuthService] Re-authentication failed: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('[AuthService] Email sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('[AuthService] Email sign-up failed: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('[AuthService] Password reset failed: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      // If signed in with Google, sign out from Google too
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (_) {
      // Error intentionally ignored - sign out should not throw
    }
  }

  /// Check if this is first sign-in for a user
  /// Used to determine if we need to migrate guest data
  bool isNewUser(UserCredential credential) {
    return credential.additionalUserInfo?.isNewUser ?? false;
  }
}
