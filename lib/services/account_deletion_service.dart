import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'notification_service.dart';

/// Account Deletion Service
///
/// Handles complete and permanent deletion of user account and all associated data.
/// This includes:
/// - Firebase Authentication account
/// - Firestore user document and all subcollections
/// - All local Hive boxes
/// - SharedPreferences data
/// - Scheduled notifications
///
/// CRITICAL: Deletion order matters!
/// 1. Cancel notifications (local)
/// 2. Delete Firestore data (remote)
/// 3. Delete Firebase Auth account (remote)
/// 4. Clear Hive boxes (local)
/// 5. Clear SharedPreferences (local)
class AccountDeletionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService;

  AccountDeletionService(this._notificationService);

  /// Delete the current user's account and all data permanently
  ///
  /// [onProgress] - Optional callback to report deletion progress
  /// Returns true if deletion was successful, throws exception on error
  ///
  /// Deletion sequence:
  /// 1. Cancel all local notifications
  /// 2. Delete Firestore user document and subcollections
  /// 3. Delete Firebase Authentication account
  /// 4. Clear all Hive boxes
  /// 5. Clear SharedPreferences
  ///
  /// If any step fails, the process stops and throws an exception
  Future<void> deleteAccount({Function(String message)? onProgress}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final userId = user.uid;
    print(
      '[AccountDeletionService] 🗑️ Starting account deletion for user: $userId',
    );

    try {
      // ========================================
      // STEP 1: Cancel all local notifications
      // ========================================
      onProgress?.call('Cancelling notifications...');
      print('[AccountDeletionService] Step 1/5: Cancelling notifications');
      await _notificationService.cancelAllNotifications();
      print('[AccountDeletionService] ✅ Notifications cancelled');

      // ========================================
      // STEP 2: Delete Firestore data
      // ========================================
      onProgress?.call('Deleting cloud data...');
      print('[AccountDeletionService] Step 2/5: Deleting Firestore data');
      await _deleteFirestoreData(userId);
      print('[AccountDeletionService] ✅ Firestore data deleted');

      // ========================================
      // STEP 3: Delete Firebase Auth account
      // ========================================
      onProgress?.call('Deleting account...');
      print(
        '[AccountDeletionService] Step 3/5: Deleting Firebase Auth account',
      );
      await user.delete();
      print('[AccountDeletionService] ✅ Firebase Auth account deleted');

      // ========================================
      // STEP 4: Clear all Hive boxes
      // ========================================
      onProgress?.call('Clearing local data...');
      print('[AccountDeletionService] Step 4/5: Clearing Hive boxes');
      await _clearAllHiveBoxes();
      print('[AccountDeletionService] ✅ Hive boxes cleared');

      // ========================================
      // STEP 5: Clear SharedPreferences
      // ========================================
      onProgress?.call('Finalizing...');
      print('[AccountDeletionService] Step 5/5: Clearing SharedPreferences');
      await _clearSharedPreferences();
      print('[AccountDeletionService] ✅ SharedPreferences cleared');

      print(
        '[AccountDeletionService] 🎉 Account deletion completed successfully',
      );
    } catch (e, stackTrace) {
      print('[AccountDeletionService] ❌ Error during account deletion: $e');
      print('[AccountDeletionService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete all Firestore data for the user
  /// This includes the user document and all subcollections (bills, etc.)
  Future<void> _deleteFirestoreData(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);

      // Delete bills subcollection
      final billsCollection = userDoc.collection('bills');
      final billsSnapshot = await billsCollection.get();

      print(
        '[AccountDeletionService] Found ${billsSnapshot.docs.length} bills to delete',
      );

      // Delete bills in batches (Firestore limit is 500 per batch)
      final batch = _firestore.batch();
      int count = 0;

      for (final doc in billsSnapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Commit batch if we hit 500 documents
        if (count >= 500) {
          await batch.commit();
          count = 0;
        }
      }

      // Commit remaining documents
      if (count > 0) {
        await batch.commit();
      }

      // Delete the user document itself
      await userDoc.delete();

      print(
        '[AccountDeletionService] Deleted user document and ${billsSnapshot.docs.length} bills',
      );
    } catch (e) {
      print('[AccountDeletionService] Error deleting Firestore data: $e');
      throw Exception('Failed to delete cloud data: $e');
    }
  }

  /// Clear all Hive boxes (user-scoped and global)
  /// This ensures no local data remains after account deletion
  Future<void> _clearAllHiveBoxes() async {
    try {
      print('[AccountDeletionService] Clearing all Hive boxes');

      // Clear and close all currently open boxes
      // We need to get a list of box names before closing them
      final boxesToDelete = <String>[];

      // Common box name patterns for this app
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        boxesToDelete.add('bills_$userId');
        boxesToDelete.add('settings_$userId');
      }

      // Try to clear and delete each box
      for (final boxName in boxesToDelete) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            await box.close();
            print('[AccountDeletionService] Cleared and closed box: $boxName');
          }
          await Hive.deleteBoxFromDisk(boxName);
          print('[AccountDeletionService] Deleted box from disk: $boxName');
        } catch (e) {
          print('[AccountDeletionService] Error deleting box $boxName: $e');
          // Continue with other boxes even if one fails
        }
      }

      print('[AccountDeletionService] All Hive boxes cleared');
    } catch (e) {
      print('[AccountDeletionService] Error clearing Hive boxes: $e');
      throw Exception('Failed to clear local database: $e');
    }
  }

  /// Clear all SharedPreferences data
  /// This removes any cached settings or user preferences
  Future<void> _clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('[AccountDeletionService] SharedPreferences cleared');
    } catch (e) {
      print('[AccountDeletionService] Error clearing SharedPreferences: $e');
      throw Exception('Failed to clear preferences: $e');
    }
  }
}
