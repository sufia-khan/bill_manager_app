import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../core/app_colors.dart';
import '../core/reminder_config.dart';
import '../models/bill.dart';
import '../providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Bill Detail View - Focused view with large typography
/// Shows bill details with Mark as Paid / Edit / Delete actions
/// Includes live countdown timer to next notification
class BillDetailView extends StatefulWidget {
  final Bill bill;
  final VoidCallback? onBack;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BillDetailView({
    super.key,
    required this.bill,
    this.onBack,
    this.onMarkPaid,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<BillDetailView> createState() => _BillDetailViewState();
}

class _BillDetailViewState extends State<BillDetailView> {
  Timer? _countdownTimer;
  Duration? _timeRemaining;
  DateTime? _notificationTime; // Store the notification time once

  @override
  void initState() {
    super.initState();
    // Calculate RAW notification time once on init (without fallback)
    if (widget.bill.reminderPreference != ReminderPreference.none) {
      _notificationTime = ReminderConfig.calculateRawNotificationTime(
        dueDate: widget.bill.dueDate,
        preference: widget.bill.reminderPreference,
        reminderHour: widget.bill.reminderTimeHour,
        reminderMinute: widget.bill.reminderTimeMinute,
        referenceTime: widget.bill.updatedAt,
      );

      // Check if already in past
      final now = DateTime.now();
      if (_notificationTime!.isBefore(now)) {
        _timeRemaining = null; // Already passed, show "Notification sent"
      }
    }
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateTimeRemaining();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTimeRemaining(),
    );
  }

  void _updateTimeRemaining() {
    if (widget.bill.reminderPreference == ReminderPreference.none ||
        _notificationTime == null) {
      return;
    }

    final now = DateTime.now();
    final remaining = _notificationTime!.difference(now);

    if (mounted) {
      setState(() {
        _timeRemaining = remaining.isNegative ? null : remaining;
      });
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use global currency setting from SettingsProvider
    final settings = context.watch<SettingsProvider>();
    final currencyFormat = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            _buildHeader(context),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    _buildStatusBadge(),
                    const SizedBox(height: 24),

                    // Bill Name
                    Text(
                      widget.bill.name,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Amount - Large Typography
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor().withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Amount',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(widget.bill.amount),
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Due Date',
                            value: dateFormat.format(widget.bill.dueDate),
                          ),
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.repeat_rounded,
                            label: 'Frequency',
                            value: widget.bill.isMonthly
                                ? 'Monthly'
                                : 'One-time',
                          ),
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.notifications_active_rounded,
                            label: 'Reminder',
                            value: widget.bill.reminderPreference.displayName,
                          ),
                          // Show notification countdown when not paid and reminder is not None
                          if (!widget.bill.paid &&
                              widget.bill.reminderPreference !=
                                  ReminderPreference.none) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _timeRemaining == null
                                              ? 'Notification sent'
                                              : 'Notification in',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (_timeRemaining != null)
                                          Text(
                                            _formatCountdown(_timeRemaining!),
                                            style: GoogleFonts.inter(
                                              fontSize: 18,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.5,
                                            ),
                                          )
                                        else
                                          Text(
                                            'Check your notifications',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.bill.isSyncPending) ...[
                            const Divider(height: 24),
                            _DetailRow(
                              icon: Icons.cloud_off_rounded,
                              label: 'Sync Status',
                              value: 'Pending sync',
                              valueColor: AppColors.pending,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Mark as Paid Button (if not paid)
                    if (!widget.bill.paid) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onMarkPaid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Mark as Paid',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Edit Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Edit Bill',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.alert,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Delete Bill',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
          ),
          const Spacer(),
          // Sync indicator
          if (widget.bill.isSynced)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_done_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Synced',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 18, color: _getStatusColor()),
          const SizedBox(width: 6),
          Text(
            _getStatusLabel(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.bill.status) {
      case BillStatus.paid:
        return AppColors.paid;
      case BillStatus.overdue:
        return AppColors.overdue;
      case BillStatus.upcoming:
        return AppColors.pending;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.bill.status) {
      case BillStatus.paid:
        return Icons.check_circle_rounded;
      case BillStatus.overdue:
        return Icons.warning_rounded;
      case BillStatus.upcoming:
        return Icons.schedule_rounded;
    }
  }

  String _getStatusLabel() {
    switch (widget.bill.status) {
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.upcoming:
        return 'Upcoming';
    }
  }
}

/// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
