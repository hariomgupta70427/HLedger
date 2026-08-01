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
  static const String lastUpdated = 'July 18, 2026';

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
              'lives. In short: your transaction data stays on your device.',
            ),
            _section(
              '1. Data We Collect',
              'HLedger stores the expense and income entries you create, '
              'your notes, tasks, and categories. When you use the optional '
              'auto-import feature, we read incoming transaction SMS from '
              'your bank and UPI apps to detect the amount and direction '
              '(money in or out). We do not collect your contacts, location, '
              'photos, or browsing activity.',
            ),
            _section(
              '2. On-Device Storage',
              'Your transactions, tasks, notes, and everything derived from '
              'SMS data are processed and stored only on your '
              'device. This data is never uploaded to our servers and is '
              'never sold or shared with third parties. Uninstalling the app '
              'removes this local data.',
            ),
            _section(
              '3. SMS Access',
              'With your explicit consent, HLedger reads incoming SMS to '
              'detect transaction messages from banks and UPI apps. We use '
              'this only to auto-create expense entries that you review '
              'before saving. Messages are scanned on your device, only '
              'financial transaction SMS are used, and the content never '
              'leaves your device. HLedger never sends SMS. You can revoke '
              'this access anytime from your phone Settings > Apps > HLedger '
              '> Permissions.',
            ),
            _section(
              '4. What SMS We Read',
              'HLedger only extracts the amount and whether money moved in or '
              'out from transaction SMS. It does not read, store, or transmit '
              'OTPs, personal messages, or any non-financial SMS.',
            ),
            _section(
              '5. AI Chat Assistant',
              'If you use the in-app AI chat, the messages you type are sent '
              'to the Groq API (groq.com) so the AI model can '
              'generate a reply. Only the text you choose to send in chat '
              'leaves the device for this feature. Your stored transactions '
              'are not sent unless you include them in a message. Please '
              'review Groq\'s own privacy terms for how they handle '
              'requests. Do not share sensitive information in chat.',
            ),
            _section(
              '6. Authentication',
              'Account sign-in and sync are powered by Supabase. When you '
              'create an account we store your email and authentication '
              'details with Supabase to keep you signed in. This is used '
              'only for authentication and any sync features you enable.',
            ),
            _section(
              '7. No Third-Party Sharing',
              'We do not sell your data. We do not share your financial data '
              'with advertisers or data brokers. The only external services '
              'involved are the ones described above (Groq for AI chat '
              'and Supabase for authentication), used solely to provide those '
              'features.',
            ),
            _section(
              '8. Your Rights',
              'You control your data. You can delete individual entries, '
              'clear all local data, revoke notification access, and delete '
              'your account. Uninstalling the app removes on-device data. To '
              'request account deletion or a data export, contact us using '
              'the details below.',
            ),
            _section(
              '9. Children\'s Privacy',
              'HLedger is not directed at children under 13, and we do not '
              'knowingly collect data from them.',
            ),
            _section(
              '10. Changes to This Policy',
              'We may update this policy from time to time. Material changes '
              'will be reflected here with a new "Last updated" date.',
            ),
            _section(
              '11. Contact',
              'Questions about privacy? Reach out at [YOUR_EMAIL].',
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
