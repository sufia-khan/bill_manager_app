import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'models/bill.dart';
import 'services/auth_service.dart';
import 'services/local_db_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'providers/bill_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bill_detail_view.dart';
import 'screens/add_bill_sheet.dart';
import 'screens/settings_screen.dart';

/// BillMinder - Bill Manager App
///
/// Offline-first bill management with cloud sync.
///
/// Architecture:
/// - Local DB: Hive (primary data source)
/// - Cloud: Firebase Firestore (backup & sync)
/// - Auth: Firebase Auth + Google Sign-In
/// - State: Provider
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize services
  final localDb = LocalDbService();
  await localDb.initialize();

  final authService = AuthService();
  final syncService = SyncService(localDb);
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize settings provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  // Set up sync if user is already signed in
  if (authService.isSignedIn) {
    syncService.setUserId(authService.currentUser?.uid);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BillProvider(
            localDb: localDb,
            syncService: syncService,
            notificationService: notificationService,
            authService: authService,
          ),
        ),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const BillMinderApp(),
    ),
  );
}

/// Main App Widget
class BillMinderApp extends StatelessWidget {
  const BillMinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillMinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppNavigator(),
    );
  }
}

/// App Navigator - Handles screen transitions
class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  AppScreen _currentScreen = AppScreen.splash;
  Bill? _selectedBill;

  @override
  void initState() {
    super.initState();
    // Load bills on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProvider>().loadBills();
    });
  }

  void _navigateTo(AppScreen screen) {
    setState(() {
      _currentScreen = screen;
      if (screen != AppScreen.detail) {
        _selectedBill = null;
      }
    });
  }

  void _openBillDetail(Bill bill) {
    setState(() {
      _selectedBill = bill;
      _currentScreen = AppScreen.detail;
    });
  }

  void _showAddBillSheet() {
    final provider = context.read<BillProvider>();

    AddBillSheet.show(
      context,
      onSave: (name, amount, dueDate, repeat) async {
        await provider.addBill(
          name: name,
          amount: amount,
          dueDate: dueDate,
          repeat: repeat,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill added successfully!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, provider, _) {
        switch (_currentScreen) {
          case AppScreen.splash:
            return SplashScreen(onComplete: () => _navigateTo(AppScreen.auth));

          case AppScreen.auth:
            return AuthScreen(
              onGoogleSignIn: () async {
                final success = await provider.signInWithGoogle();
                if (success && mounted) {
                  _navigateTo(AppScreen.home);
                }
              },
              onGuestContinue: () async {
                await provider.continueAsGuest();
                if (mounted) {
                  _navigateTo(AppScreen.home);
                }
              },
            );

          case AppScreen.home:
            return HomeScreen(
              bills: provider.billsSortedByDueDate,
              onBillTap: _openBillDetail,
              onSettingsTap: () => _navigateTo(AppScreen.settings),
              onAddTap: _showAddBillSheet,
            );

          case AppScreen.detail:
            if (_selectedBill == null) {
              return HomeScreen(
                bills: provider.billsSortedByDueDate,
                onBillTap: _openBillDetail,
                onSettingsTap: () => _navigateTo(AppScreen.settings),
                onAddTap: _showAddBillSheet,
              );
            }

            // Get fresh bill data from provider
            final freshBill =
                provider.getBill(_selectedBill!.id) ?? _selectedBill!;

            return BillDetailView(
              bill: freshBill,
              onBack: () => _navigateTo(AppScreen.home),
              onMarkPaid: () async {
                await provider.markBillPaid(freshBill.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        freshBill.isMonthly
                            ? 'Marked paid! Next month\'s bill created.'
                            : 'Bill marked as paid!',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _navigateTo(AppScreen.home);
                }
              },
              onEdit: () {
                // TODO: Implement edit functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit feature coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onDelete: () async {
                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Bill'),
                    content: Text(
                      'Are you sure you want to delete "${freshBill.name}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF43F5E),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await provider.deleteBill(freshBill.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bill deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _navigateTo(AppScreen.home);
                }
              },
            );

          case AppScreen.settings:
            return SettingsScreen(
              onBack: () => _navigateTo(AppScreen.home),
              onSignOut: () async {
                await provider.signOut();
                if (mounted) {
                  _navigateTo(AppScreen.auth);
                }
              },
              onSignIn: () async {
                final success = await provider.signInWithGoogle();
                if (success && mounted) {
                  setState(() {}); // Refresh to show signed-in state
                }
              },
              isGuest: provider.isGuest,
              userEmail: provider.userEmail,
            );
        }
      },
    );
  }
}

/// App screens enum
enum AppScreen { splash, auth, home, detail, settings }
