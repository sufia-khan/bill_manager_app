import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_info.dart';

/// Terms of Service Screen
/// Displays the app's terms of service
class TermsOfServiceScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const TermsOfServiceScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      '1. Acceptance of Terms',
                      'By using BillMinder ("App"), you agree to these Terms of Service. If you do not agree, do not use the App.',
                    ),
                    _buildSection(
                      '2. Purpose of the App',
                      'The App is intended solely for personal bill tracking and reminder management. It does not provide financial, legal, or professional advice.',
                    ),
                    _buildSection(
                      '3. User Responsibility',
                      '• Users are solely responsible for the accuracy of the information they enter.\n\n'
                          '• The App does not verify bills, payments, or due dates.\n\n'
                          '• Users should not rely exclusively on the App for critical financial obligations.',
                    ),
                    _buildSection(
                      '4. Reminders & Notifications',
                      'Reminders are provided as a convenience feature only. We do not guarantee delivery, timing accuracy, or reliability of notifications due to:\n\n'
                          '• Device settings\n'
                          '• OS restrictions\n'
                          '• Network issues\n'
                          '• Battery optimization',
                    ),
                    _buildSection(
                      '5. Accounts & Guest Mode',
                      '• Users may use the App without signing in (Guest Mode).\n\n'
                          '• Guest data remains on the device unless the user chooses to sign in.\n\n'
                          '• Signed-in users can sync data across devices using Google Sign-In.',
                    ),
                    _buildSection(
                      '6. Account Deletion',
                      'Users may delete their account at any time. This will:\n\n'
                          '• Permanently delete associated cloud data\n'
                          '• Remove local data from the device\n\n'
                          'Deletion may take a short period to fully propagate.',
                    ),
                    _buildSection(
                      '7. Limitation of Liability',
                      'The App is provided "as is" and "as available." We are not liable for:\n\n'
                          '• Missed payments\n'
                          '• Financial loss\n'
                          '• Data loss\n'
                          '• Indirect or consequential damages',
                    ),
                    _buildSection(
                      '8. Changes to Terms',
                      'We may update these Terms. Continued use of the App constitutes acceptance of the updated Terms.',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Last updated: ${AppInfo.legalDocumentsLastUpdated}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
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
          Expanded(
            child: Text(
              'Terms of Service',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
