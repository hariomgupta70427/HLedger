import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'privacy_policy_screen.dart';

/// Prominent in-app disclosure shown before either auto-detection source is
/// enabled.
///
/// Google Play REQUIRES this disclosure BEFORE the permission is requested —
/// before `SmsTransactionService.requestPermission()` or
/// `requestNotificationAccess()` — with affirmative consent from the user.
///
/// Usage:
/// ```dart
/// final accepted = await ProminentDisclosure.showForSms(context);
/// if (accepted) {
///   await SmsTransactionService.instance.requestPermission();
/// }
/// ```
class ProminentDisclosure {
  const ProminentDisclosure._();

  /// Disclosure for reading bank and UPI transaction SMS.
  static Future<bool> showForSms(BuildContext context) => _show(context, _sms);

  /// Disclosure for reading notifications posted by banking and UPI apps.
  static Future<bool> showForNotifications(BuildContext context) =>
      _show(context, _notifications);

  static Future<bool> _show(BuildContext context, _Disclosure copy) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _ProminentDisclosureDialog(copy: copy),
    );
    return result ?? false;
  }

  static const _sms = _Disclosure(
    title: 'Auto-read transaction SMS',
    intro: 'To auto-add your expenses, HLedger needs to read the '
        'transaction SMS that your bank and UPI apps '
        '(GPay, PhonePe, Paytm, etc.) send you.',
    points: [
      _Point(
        icon: Icons.sms_outlined,
        iconColor: AppColors.accent,
        title: 'What we read',
        body: 'Only transaction SMS from banks and UPI apps — the amount, and '
            'whether it was money in or out. Messages from a personal number '
            'are discarded unread. We never read OTPs, and we never send SMS.',
      ),
      _Point(
        icon: Icons.auto_awesome_outlined,
        iconColor: AppColors.yellow,
        title: 'Why we need it',
        body: 'So we can auto-create expense entries for you, bina manually '
            'type kiye. You still review each one before it is saved.',
      ),
      _Point(
        icon: Icons.phone_android_outlined,
        iconColor: AppColors.green,
        title: 'Stays on your phone',
        body: 'This data is processed and stored ONLY on this device. It is '
            'never uploaded to any server, and never shared with anyone.',
      ),
      _Point(
        icon: Icons.toggle_off_outlined,
        iconColor: AppColors.info,
        title: 'You are in control',
        body: 'You can turn this off anytime from your phone '
            'Settings > Apps > HLedger > Permissions > SMS.',
      ),
    ],
  );

  static const _notifications = _Disclosure(
    title: 'Let HLedger spot your payments',
    intro: 'When you pay with GPay, PhonePe, Paytm or Amazon Pay, there is often '
        'no SMS at all — only the app\'s own notification. Android calls this '
        'permission "Notification access", and the next screen is Android\'s, '
        'not ours.',
    points: [
      _Point(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: AppColors.accent,
        title: 'What HLedger looks at',
        body: 'Only notifications from payment and banking apps — GPay, '
            'PhonePe, Paytm, Amazon Pay, BHIM, CRED, your bank, and others like '
            'them. From those, just the amount and whether money came in or '
            'went out.',
      ),
      _Point(
        icon: Icons.chat_bubble_outline,
        iconColor: AppColors.green,
        title: 'What it does not touch',
        body: 'WhatsApp, Snapchat, Discord, Instagram, email, and every other '
            'app are skipped without being opened. They are not on HLedger\'s '
            'payment-app list, so their notifications are never read or saved.',
      ),
      _Point(
        icon: Icons.phone_android_outlined,
        iconColor: AppColors.yellow,
        title: 'Nothing is uploaded',
        body: 'A detected payment waits on this phone until you confirm it. The '
            'notification text is never sent to us or to anyone else — we do '
            'not even have a server that could receive it.',
      ),
      _Point(
        icon: Icons.toggle_off_outlined,
        iconColor: AppColors.info,
        title: 'Off whenever you want',
        body: 'Turn it off anytime in Android Settings, or from this screen. '
            'HLedger keeps working — you just add those payments yourself. Not '
            'every payment can be caught this way, so do check your Khaata.',
      ),
    ],
    allowLabel: 'Allow payment detection',
  );
}

class _Disclosure {
  const _Disclosure({
    required this.title,
    required this.intro,
    required this.points,
    this.allowLabel = 'Allow',
  });

  final String title;
  final String intro;
  final List<_Point> points;
  final String allowLabel;
}

class _Point {
  const _Point({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
}

class _ProminentDisclosureDialog extends StatelessWidget {
  const _ProminentDisclosureDialog({required this.copy});

  final _Disclosure copy;

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
                copy.intro,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ...copy.points.map(_buildPoint),
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
            copy.title,
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

  Widget _buildPoint(_Point point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: point.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(point.icon, color: point.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  point.body,
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
              copy.allowLabel,
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
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
          child: Text(
            'Read the Privacy Policy',
            style: GoogleFonts.inter(
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textSecondary,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
