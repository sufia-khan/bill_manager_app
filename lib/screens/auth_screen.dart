import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/bill_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Auth Screen - Google Sign-in
/// Clean, minimal layout
class AuthScreen extends StatefulWidget {
  final Future<bool> Function()? onGoogleSignIn;

  const AuthScreen({super.key, this.onGoogleSignIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isWaitingForAccount = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    if (_isWaitingForAccount || widget.onGoogleSignIn == null) {
      return;
    }

    setState(() {
      _isWaitingForAccount = true;
      _errorMessage = null;
    });

    try {
      // Pass a callback that will be triggered when an account is selected
      // This allows the loading indicator to show ONLY after the user picks an account
      final success = await widget.onGoogleSignIn!();

      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Sign-in was cancelled or failed. Please try again.';
        });
        // Only show snackbar if it wasn't a simple cancel (handled by provider)
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWaitingForAccount = false;
          // Note: _isSigningIn is managed by the provider/consumer
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Welcome illustration/icon - App Logo
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(70),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Welcome text
              Text(
                'Welcome to',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BillMinder',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your bills, never miss a payment,\nand stay on top of your finances.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // Google Sign In Button with loading state
              Consumer<BillProvider>(
                builder: (context, provider, _) {
                  return _GoogleSignInButton(
                    onPressed: (provider.isLoading || _isWaitingForAccount)
                        ? null
                        : _handleGoogleSignIn,
                    isLoading: provider.isLoading,
                  );
                },
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google Sign In Button Widget
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GoogleSignInButton({this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google Icon (simplified)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
