import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Prominent in-app disclosure for the notification-listener feature.
///
/// Google Play REQUIRES that this disclosure is shown to the user BEFORE
/// requesting `NotificationListenerService` access (i.e. before calling
/// `SmsTransactionService.requestPermission()`), and that the user gives
/// affirmative consent.
///
/// Usage:
/// ```dart
/// final accepted = await ProminentDisclosure.show(context);
/// if (accepted) {
///   await SmsTransactionService.instance.requestPermission();
/// }
/// ```
class ProminentDisclosure {
  const ProminentDisclosure._();

  /// Shows the prominent disclosure modal.
  ///
  /// Returns `true` if the user tapped "Allow" (affirmative consent),
  /// `false` if they tapped "Not now" or dismissed the dialog.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _ProminentDisclosureDialog(),
    );
    return result ?? false;
  }
}

class _ProminentDisclosureDialog extends StatelessWidget {
  const _ProminentDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Text(
                'To auto-add your expenses, HLedger needs to read the '
                'transaction notifications that your bank and UPI apps '
                '(GPay, PhonePe, Paytm, etc.) show you.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildPoint(
                icon: Icons.notifications_active_outlined,
                iconColor: AppColors.accent,
                title: 'What we read',
                body: 'Only transaction notifications from bank and UPI '
                    'apps — the amount, and whether it was money in or out.',
              ),
              _buildPoint(
                icon: Icons.auto_awesome_outlined,
                iconColor: AppColors.yellow,
                title: 'Why we need it',
                body: 'So we can auto-create expense entries for you, bina '
                    'manually type kiye. You still review each one before '
                    'it is saved.',
              ),
              _buildPoint(
                icon: Icons.phone_android_outlined,
                iconColor: AppColors.green,
                title: 'Stays on your phone',
                body: 'This data is processed and stored ONLY on this '
                    'device. It is never uploaded to any server, and never '
                    'shared with anyone.',
              ),
              _buildPoint(
                icon: Icons.toggle_off_outlined,
                iconColor: AppColors.info,
                title: 'You are in control',
                body: 'You can turn this off anytime from your phone '
                    'Settings > Notification access, ya app ki settings se.',
              ),
              const SizedBox(height: 24),
              _buildButtons(context),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.privacy_tip_outlined,
            color: AppColors.accent,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Auto-read transaction notifications',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoint({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Allow',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Not now',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
