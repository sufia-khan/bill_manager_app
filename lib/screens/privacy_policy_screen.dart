import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_info.dart';

/// Privacy Policy Screen
/// Displays the app's privacy policy
class PrivacyPolicyScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const PrivacyPolicyScreen({super.key, this.onBack});

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
                    _buildSection('1. Information We Collect', null),
                    _buildSubSection(
                      'a. Authentication Data (Optional)',
                      'If you sign in using Google:\n\n'
                          '• Email address\n'
                          '• Display name\n'
                          '• Firebase UID\n\n'
                          'This is used only for account identification and data sync.',
                    ),
                    _buildSubSection(
                      'b. User-Created Bill Data',
                      'Data you choose to enter, such as:\n\n'
                          '• Bill names\n'
                          '• Amounts\n'
                          '• Due dates\n'
                          '• Recurrence\n'
                          '• Reminder preferences',
                    ),
                    _buildSection(
                      '2. How Data Is Used',
                      '• To store and display your bills\n'
                          '• To send reminders\n'
                          '• To sync data across devices (if signed in)',
                    ),
                    _buildSection('3. Data Storage', null),
                    _buildDataStorageTable(),
                    const SizedBox(height: 24),
                    _buildSection(
                      '4. Guest Mode',
                      'In Guest Mode:\n\n'
                          '• Data remains stored locally on your device\n'
                          '• We do not intentionally transmit guest data to our servers\n'
                          '• Users may later migrate data by signing in',
                    ),
                    _buildSection(
                      '5. Third-Party Services',
                      'We use:\n\n'
                          '• Google Sign-In & Firebase (authentication and sync)\n'
                          '• Google Fonts (typography)\n\n'
                          'These services process data according to their own privacy policies.',
                    ),
                    _buildSection(
                      '6. Data Security',
                      'We apply reasonable safeguards, including:\n\n'
                          '• Firebase security rules\n'
                          '• Access control by user ID\n\n'
                          'However, no system is 100% secure.',
                    ),
                    _buildSection(
                      '7. Data Deletion',
                      'Users may delete their account and associated data at any time from within the App.',
                    ),
                    _buildSection(
                      '8. Children\'s Privacy',
                      'The App is not intended for users under 13.',
                    ),
                    _buildSection(
                      '9. Changes to This Policy',
                      'We may update this Privacy Policy. Updates will be reflected within the App.',
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
              'Privacy Policy',
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

  Widget _buildSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          if (content != null) ...[
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
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
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

  Widget _buildDataStorageTable() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Location',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Description',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          _buildTableRow('On device', 'Local storage for offline use'),
          _buildTableRow(
            'Firebase Firestore',
            'Optional cloud sync for signed-in users',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String location,
    String description, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              location,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
