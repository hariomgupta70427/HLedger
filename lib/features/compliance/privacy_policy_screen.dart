import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// In-app Privacy Policy screen.
///
/// Mirrors the hosted policy at `PRIVACY_POLICY.md`. Keep the two in sync
/// whenever the policy changes. This screen is safe to push onto the
/// navigation stack from Settings or from the prominent disclosure flow.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Update this whenever the policy text below changes.
  static const String lastUpdated = 'August 20, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'HLedger Privacy Policy',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Last updated: $lastUpdated',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _intro(
              'HLedger is built privacy-first. Your financial data is your '
              'own. This policy explains what we access, why, and where it '
              'lives. In short: nothing leaves your device except what is '
              'needed to sign you in and sync entries back to your own '
              'account.',
            ),
            _section(
              '1. Data We Collect',
              'HLedger stores the expense and income entries you create, '
              'your notes, tasks, and categories. When you turn on the optional '
              'auto-detect feature, we read transaction alerts from your bank '
              'and UPI apps — from their notifications, from their SMS, or '
              'both, depending on which sources you enable — to detect the '
              'amount and direction (money in or out). We do not collect your '
              'contacts, location, photos, or browsing activity.',
            ),
            _section(
              '2. Where Your Data Lives',
              'Detected transactions waiting for your review, and your chat '
              'history, stay on your device and are never uploaded. Raw SMS '
              'text and raw notification text never leave your device at any '
              'point. Entries you save are stored on your device and synced to '
              'your own private account so they survive a reinstall or a new '
              'phone — see section 7. This data is never sold or shared with '
              'third parties. Uninstalling the app removes the local copy.',
            ),
            _section(
              '3. Notification Access (optional)',
              'With your explicit consent, HLedger uses Android\'s '
              'Notification Listener to read incoming transaction alerts from '
              'bank and UPI apps, only to suggest entries you review before '
              'saving. We read notifications from a fixed allowlist of '
              'banking, UPI and wallet apps only — notifications from every '
              'other app on your device, including messaging and email, are '
              'not opened and not stored. Captured alerts are held in '
              'app-private storage on your device until you review them, then '
              'deleted. You can revoke this anytime from Settings > '
              'Notification access, or from the Review Inbox in HLedger.',
            ),
            _section(
              '4. SMS Access (optional)',
              'With your explicit consent, HLedger reads incoming SMS to '
              'detect transaction messages from banks and UPI apps. This '
              'exists because many Indian banks announce a transaction only by '
              'SMS. We read the message body and sender only to extract an '
              'amount, a direction, a counterparty and a reference number. '
              'Messages from an ordinary phone number are discarded without '
              'being parsed, and messages containing a one-time password are '
              'rejected before any figure is extracted. HLedger never sends '
              'SMS. Raw SMS content is never transmitted off the device, and '
              'never sent to the AI provider in section 6. You can revoke this '
              'anytime from Settings > Apps > HLedger > Permissions > SMS.',
            ),
            _section(
              '5. Auto-detect Is Not Complete, By Design',
              'Auto-detect is a convenience, not a system of record. Cash '
              'transactions cannot be detected at all, and some apps and banks '
              'announce transactions in ways the app cannot read. Every '
              'detected transaction is shown to you for confirmation before it '
              'is saved, and anything missed can be added manually. HLedger '
              'never books an entry to your ledger without your confirmation.',
            ),
            _section(
              '6. AI Chat Assistant',
              'If you use the in-app AI chat, the messages you type are sent '
              'to the Groq API (groq.com), and if Groq is unavailable to the '
              'Google Gemini API, so a model can generate a reply. Only the '
              'text you choose to send in chat leaves the device for this '
              'feature, along with the recent chat turns needed for context. '
              'Your stored transactions, your SMS and your notifications are '
              'not sent to either provider unless you personally type that '
              'information into a message. Please review Groq\'s and Google\'s '
              'own privacy terms. Do not share sensitive information in chat.',
            ),
            _section(
              '7. Authentication & Sync',
              'Account sign-in and sync are powered by Google Firebase — '
              'Firebase Authentication for sign-in and Cloud Firestore for '
              'sync. When you create an account we store your email and '
              'authentication details with Firebase to keep you signed in, '
              'and the entries you save are written to your own area of the '
              'database. Security rules restrict every record to the account '
              'that created it, so no other user can read your data. Review '
              'Google\'s privacy terms for how they handle this.',
            ),
            _section(
              '8. No Third-Party Sharing',
              'We do not sell your data. We do not share your financial data '
              'with advertisers or data brokers. The only external services '
              'involved are the ones described above (Groq and Google Gemini '
              'for AI chat, Google Firebase for authentication and sync), used '
              'solely to provide those features.',
            ),
            _section(
              '9. Your Rights',
              'You control your data. You can delete individual entries, '
              'clear all local data, and revoke notification and SMS access '
              'anytime. To delete your account, go to the settings icon on the '
              'Home tab, then Account, then Delete my account — this '
              'permanently removes your account, every saved transaction and '
              'task, and all data on this device, with no way to recover it. '
              'The same instructions are published at '
              'https://hledger-ai-worker.guptahariom049.workers.dev/delete-account if you no longer have the app '
              'installed. Uninstalling alone does not delete your account.',
            ),
            _section(
              '10. Children\'s Privacy',
              'HLedger is not directed at children under 13, and we do not '
              'knowingly collect data from them.',
            ),
            _section(
              '11. Changes to This Policy',
              'We may update this policy from time to time. Material changes '
              'will be reflected here with a new "Last updated" date.',
            ),
            _section(
              '12. Contact',
              'Questions about privacy? Reach out at guptahariom049@gmail.com.',
            ),
            const SizedBox(height: 8),
            Text(
              'By using HLedger you agree to this Privacy Policy.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          height: 1.55,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
            body,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
