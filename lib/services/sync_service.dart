import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/bill.dart';
import 'local_db_service.dart';

/// Sync Service - Firebase Firestore synchronization
///
/// Handles cloud backup and cross-device sync.
/// Uses last-write-wins conflict resolution.
///
/// Key features:
/// - Silent background sync
/// - Never blocks UI
/// - Last-write-wins conflict resolution
/// - Auto-sync when online
class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final LocalDbService _localDb;

  String? _userId;
  bool _isSyncing = false;

  SyncService(this._localDb);

  /// Set the current user ID for sync operations
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Check if user is logged in (can sync)
  bool get canSync => _userId != null;

  /// Check if we're currently syncing
  bool get isSyncing => _isSyncing;

  /// Reference to user's bills collection
  CollectionReference<Map<String, dynamic>> get _billsCollection {
    if (_userId == null) {
      throw StateError('User not logged in. Cannot access Firestore.');
    }
    return _firestore.collection('users').doc(_userId).collection('bills');
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Sync all pending bills to Firestore
  /// Called when:
  /// - App opens/resumes
  /// - Internet becomes available
  /// - After local changes
  Future<void> syncPendingBills() async {
    if (!canSync || _isSyncing) return;

    final online = await isOnline();
    if (!online) return;

    _isSyncing = true;

    try {
      final pendingBills = _localDb.getPendingSyncBills();

      for (final bill in pendingBills) {
        await _uploadBill(bill);
        await _localDb.markBillSynced(bill.id);
      }

      await _localDb.setLastSyncTime(DateTime.now());
    } catch (e) {
      print('Error syncing bills: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload a single bill to Firestore
  Future<void> _uploadBill(Bill bill) async {
    try {
      await _billsCollection
          .doc(bill.id)
          .set(bill.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print('Error uploading bill ${bill.id}: $e');
      rethrow;
    }
  }

  /// Download all bills from Firestore
  /// Used for initial sync or full refresh
  Future<void> downloadAllBills() async {
    if (!canSync) return;

    final online = await isOnline();
    if (!online) return;

    _isSyncing = true;

    try {
      final snapshot = await _billsCollection.get();

      for (final doc in snapshot.docs) {
        final remoteBill = Bill.fromFirestore(doc.id, doc.data());
        final localBill = _localDb.getBill(doc.id);

        // Last-write-wins: use the most recently updated version
        if (localBill == null) {
          // New bill from cloud
          await _localDb.upsertBills([remoteBill]);
        } else if (remoteBill.updatedAt.isAfter(localBill.updatedAt)) {
          // Remote is newer
          await _localDb.upsertBills([remoteBill]);
        }
        // If local is newer, it will be synced in the next syncPendingBills call
      }

      await _localDb.setLastSyncTime(DateTime.now());
    } catch (e) {
      print('Error downloading bills: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Full sync: upload pending then download new
  Future<void> fullSync() async {
    await syncPendingBills();
    await downloadAllBills();
  }

  /// Delete a bill from Firestore
  Future<void> deleteBillFromCloud(String billId) async {
    if (!canSync) return;

    final online = await isOnline();
    if (!online) return;

    try {
      await _billsCollection.doc(billId).delete();
    } catch (e) {
      print('Error deleting bill from cloud: $e');
    }
  }

  /// Listen for real-time changes from Firestore
  /// Returns a stream of bills from the cloud
  Stream<List<Bill>>? listenToCloudChanges() {
    if (!canSync) return null;

    return _billsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bill.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }
}
