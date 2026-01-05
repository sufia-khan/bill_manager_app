import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/settings_provider.dart';
import '../providers/bill_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

/// Settings Screen - Categorized list view with consistent iconography
/// Account section, preferences (notifications, currency), sign out, and app info
class SettingsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onSignIn;
  final VoidCallback? onAccountDeleted;
  final String? userEmail;
  final bool isGuest;

  const SettingsScreen({
    super.key,
    this.onBack,
    this.onSignOut,
    this.onSignIn,
    this.onAccountDeleted,
    this.userEmail,
    this.isGuest = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Settings Content
            Expanded(
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Account Section
                      _buildSectionTitle('Account'),
                      const SizedBox(height: 12),
                      _buildAccountCard(),
                      const SizedBox(height: 28),

                      // Preferences Section
                      _buildSectionTitle('Preferences'),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        children: [
                          // Notifications Toggle
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Bill reminders and alerts',
                            trailing: Switch.adaptive(
                              value: settings.notificationsEnabled,
                              onChanged: (value) async {
                                await settings.toggleNotifications(value);
                                if (value && context.mounted) {
                                  // Re-schedule all reminders if enabled
                                  context
                                      .read<BillProvider>()
                                      .rescheduleAllReminders();
                                }
                              },
                              activeColor: AppColors.primary,
                            ),
                          ),
                          const Divider(height: 1),
                          // Currency Selector
                          _CurrencyTile(
                            currentCurrency: settings.selectedCurrency,
                            availableCurrencies: settings.availableCurrencies,
                            onCurrencySelected: (currency) {
                              settings.setCurrency(currency);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // About Section
                      _buildSectionTitle('About'),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        children: [
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            title: 'Terms of Service',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TermsOfServiceScreen(
                                    onBack: () => Navigator.pop(context),
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PrivacyPolicyScreen(
                                    onBack: () => Navigator.pop(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Sign Out Button (if signed in)
                      if (!isGuest) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _showSignOutConfirmDialog(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.alert,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: AppColors.alert.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.alert,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Sign Out',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.alert,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Footer
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'BillMinder',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Made with ❤️',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAccountCard() {
    if (isGuest) {
      return _GuestAccountCard(onSignIn: onSignIn);
    }

    return _ExpandableAccountCard(
      userEmail: userEmail,
      onDeleteAccount: _showDeleteAccountDialog,
    );
  }

  /// Show sign out confirmation dialog
  void _showSignOutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.alert,
          size: 48,
        ),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (onSignOut != null) {
                onSignOut!();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show delete account confirmation dialog
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_rounded,
          color: AppColors.alert,
          size: 48,
        ),
        title: Text(
          'Delete Account?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.alert,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The following will be permanently deleted:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...['All your bills', 'Cloud backup data', 'Account settings'].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleDeleteAccount(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete Account',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle account deletion with loading overlay
  Future<void> _handleDeleteAccount(BuildContext context) async {
    final provider = context.read<BillProvider>();

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x66000000),
      builder: (overlayContext) => PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.alert,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Deleting Account...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Execute deletion
    final success = await provider.deleteAccount();

    // Close loading overlay
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (success) {
      // Navigate to login screen on success
      if (context.mounted && onAccountDeleted != null) {
        onAccountDeleted!();
      }
    } else {
      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (errorContext) => AlertDialog(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.alert,
              size: 48,
            ),
            title: Text(
              'Deletion Failed',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              provider.error ??
                  'An error occurred while deleting your account.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(errorContext),
                child: const Text('OK'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(errorContext);
                  _handleDeleteAccount(context);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }
}

/// Expandable Account Card - tap to reveal Delete Account option
class _ExpandableAccountCard extends StatefulWidget {
  final String? userEmail;
  final void Function(BuildContext context) onDeleteAccount;

  const _ExpandableAccountCard({
    required this.userEmail,
    required this.onDeleteAccount,
  });

  @override
  State<_ExpandableAccountCard> createState() => _ExpandableAccountCardState();
}

class _ExpandableAccountCardState extends State<_ExpandableAccountCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        // Account info row - tappable to expand
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: _isExpanded
              ? const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                )
              : BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.userEmail?.substring(0, 1).toUpperCase() ?? 'U',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.userEmail ?? 'User',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated Delete Account section
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              // Delete Account tile
              InkWell(
                onTap: () => widget.onDeleteAccount(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.alert.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                          color: AppColors.alert,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Account',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.alert,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permanently remove your account and data',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// Guest Account Card with Sign-in Loading State
class _GuestAccountCard extends StatefulWidget {
  final Future<void> Function()? onSignIn;

  const _GuestAccountCard({this.onSignIn});

  @override
  State<_GuestAccountCard> createState() => _GuestAccountCardState();
}

class _GuestAccountCardState extends State<_GuestAccountCard> {
  bool _isWaitingForAccount = false;

  Future<void> _handleSignIn() async {
    if (widget.onSignIn == null || _isWaitingForAccount) return;

    setState(() {
      _isWaitingForAccount = true;
    });

    try {
      await widget.onSignIn!();
    } finally {
      if (mounted) {
        setState(() {
          _isWaitingForAccount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, provider, _) {
        final isLoading = provider.isLoading;

        return _SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Guest Mode',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to sync your bills across devices',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isLoading || _isWaitingForAccount)
                          ? null
                          : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.6,
                        ),
                        disabledForegroundColor: Colors.white.withOpacity(0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isLoading
                                  ? 'Signing in...'
                                  : 'Sign in with Google',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Settings Card Container
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

/// Settings Tile Widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Currency Selector Tile
class _CurrencyTile extends StatelessWidget {
  final Currency currentCurrency;
  final List<Currency> availableCurrencies;
  final Function(Currency) onCurrencySelected;

  const _CurrencyTile({
    required this.currentCurrency,
    required this.availableCurrencies,
    required this.onCurrencySelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCurrencyPicker(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  currentCurrency.symbol,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currentCurrency.name} (${currentCurrency.code})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CurrencyPickerSheet(
        currentCurrency: currentCurrency,
        currencies: availableCurrencies,
        onSelect: (currency) {
          onCurrencySelected(currency);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Currency Picker Bottom Sheet
class _CurrencyPickerSheet extends StatelessWidget {
  final Currency currentCurrency;
  final List<Currency> currencies;
  final Function(Currency) onSelect;

  const _CurrencyPickerSheet({
    required this.currentCurrency,
    required this.currencies,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Select Currency',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Currency List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final currency = currencies[index];
                final isSelected = currency == currentCurrency;

                return InkWell(
                  onTap: () => onSelect(currency),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.15)
                                : AppColors.surfaceDim,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              currency.symbol,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                currency.code,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
