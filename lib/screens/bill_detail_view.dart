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

  @override
  void initState() {
    super.initState();
    // Calculate RAW notification time once on init (without fallback)
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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

                    // Amount - Large Typography with Orange Highlight
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Amount',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormat.format(widget.bill.amount),
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _buildStatusBadge(onPrimary: true),
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
                            value:
                                widget.bill.reminderPreference ==
                                    ReminderPreference.none
                                ? 'None'
                                : '${widget.bill.reminderPreference.displayName} at ${widget.bill.reminderTime.format(context)}',
                          ),
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
                            backgroundColor: AppColors.paid,
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
        ],
      ),
    );
  }

  Widget _buildStatusBadge({bool onPrimary = false}) {
    final color = onPrimary ? Colors.white : _getStatusColor();
    final bgColor = onPrimary
        ? Colors.white.withOpacity(0.2)
        : _getStatusColor().withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: onPrimary
            ? Border.all(color: Colors.white.withOpacity(0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusLabel(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
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
      case BillStatus.dueToday:
        return AppColors.dueToday;
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
      case BillStatus.dueToday:
        return Icons.event_available_rounded;
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
      case BillStatus.dueToday:
        return 'Due Today';
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

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
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
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
