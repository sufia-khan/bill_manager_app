import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'core/app_lifecycle_observer.dart';
import 'models/bill.dart';
import 'services/auth_service.dart';
import 'services/local_db_service.dart';
import 'services/smart_sync_service.dart';
import 'services/notification_service.dart';
import 'providers/bill_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bill_detail_view.dart';
import 'screens/add_bill_sheet.dart';
import 'screens/settings_screen.dart';
import 'core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize auth service first to check current user
  final authService = AuthService();

  // Get user ID: Firebase UID for signed-in users
  // CRITICAL: This ensures each user has isolated data storage
  String? userId;
  if (authService.userId != null) {
    // User is already signed in with Google
    userId = authService.userId!;
    print('[main] Initializing for Firebase user: $userId');
  } else {
    // User needs to sign in - initialize without user ID
    // LocalDB will be initialized after sign-in
    print('[main] No user signed in - waiting for authentication');
  }

  // Initialize services - they'll be properly configured after sign-in if needed
  // LocalDB won't open boxes until switchUser is called with a valid user ID
  final localDb = LocalDbService();
  final syncService = SmartSyncService(localDb);
  await syncService.initialize();

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize settings provider
  final settingsProvider = SettingsProvider(notificationService);
  await settingsProvider.initialize();

  // If user is already signed in, initialize their data
  if (authService.userId != null) {
    final userId = authService.userId!;
    print('[main] User already signed in: $userId');

    await localDb.initialize(userId);
    syncService.setUserId(userId);
    notificationService.setUserId(userId);

    // Add lifecycle observer for sync
    final lifecycleObserver = AppLifecycleObserver(syncService);
    WidgetsBinding.instance.addObserver(lifecycleObserver);
  } else {
    print('[main] No user signed in - will initialize after sign-in');
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
  bool _minimumSplashTimeElapsed = false;

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
      onSave:
          (
            name,
            amount,
            dueDate,
            repeat,
            reminderPreference,
            currencyCode,
            reminderTime, // Added time parameter
          ) async {
            await provider.addBill(
              name: name,
              amount: amount,
              dueDate: dueDate,
              repeat: repeat,
              reminderPreference: reminderPreference,
              currencyCode: currencyCode,
              reminderTimeHour: reminderTime.hour, // Pass hour
              reminderTimeMinute: reminderTime.minute, // Pass minute
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
        // Automatic transition from splash when ready
        if (_currentScreen == AppScreen.splash &&
            _minimumSplashTimeElapsed &&
            !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.isSignedIn) {
              _navigateTo(AppScreen.home);
            } else {
              _navigateTo(AppScreen.auth);
            }
          });
        }

        switch (_currentScreen) {
          case AppScreen.splash:
            return SplashScreen(
              isLoading: provider.isLoading,
              onComplete: () {
                setState(() {
                  _minimumSplashTimeElapsed = true;
                });
              },
            );

          case AppScreen.auth:
            return AuthScreen(
              onGoogleSignIn: () async {
                final success = await provider.signInWithGoogle();
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed in successfully!'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _navigateTo(AppScreen.home);
                } else if (!success && mounted && provider.error != null) {
                  // Show the user-friendly error from BillProvider
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error!),
                      backgroundColor: const Color(0xFFF43F5E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return success;
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
                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.paid,
                      size: 40,
                    ),
                    title: Text(
                      'Mark as Paid?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      'Have you already paid "${freshBill.name}"?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Not yet',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.paid,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Yes, Mark Paid',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  ),
                );

                if (confirm == true && mounted) {
                  await provider.markBillPaid(freshBill.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          freshBill.isMonthly
                              ? 'Marked paid! Next month\'s bill created.'
                              : 'Bill marked as paid!',
                        ),
                        backgroundColor: AppColors.paid,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    _navigateTo(AppScreen.home);
                  }
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.alert,
                      size: 40,
                    ),
                    title: Text(
                      'Delete Bill?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      'Are you sure you want to delete "${freshBill.name}"? This cannot be undone.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.alert,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Delete Now',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  ),
                );

                if (confirm == true && mounted) {
                  await provider.deleteBill(freshBill.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bill deleted'),
                      backgroundColor: AppColors.dark,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
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
              onAccountDeleted: () {
                // Navigate to auth screen after account deletion
                if (mounted) {
                  _navigateTo(AppScreen.auth);
                }
              },
              userEmail: provider.userEmail,
              isGuest: !provider.isSignedIn,
            );
        }
      },
    );
  }
}

/// App screens enum
enum AppScreen { splash, auth, home, detail, settings }
