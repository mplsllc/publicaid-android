import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets/app_menu.dart';

class DocsScreen extends StatelessWidget {
  final void Function(String) onNavigate;

  const DocsScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Documentation'),
        actions: [AppMenuButton(onNavigate: onNavigate)],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to Use Publicaid',
              style: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 26,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 20),
            _section(context,
              '1. Finding Services',
              'Search by service type, organization name, or general need. '
                  'Results are ranked by relevance and match against organization names, '
                  'descriptions, services offered, and categories.',
            ),
            _section(context,
              '2. Filtering Results',
              'Filter by state, category, city, language, payment type '
                  '(Medicaid, sliding scale, free), population served '
                  '(veterans, youth, seniors), and accessibility features.',
            ),
            _section(context,
              '3. Using Your Location',
              'Enable location services or enter a ZIP code to find nearby results. '
                  'Your location is used for that one search and immediately discarded. '
                  'It is never saved, never logged, and never tied to what you searched for.',
            ),
            _section(context,
              '4. The Guide',
              'Not sure what to search for? Use the Guided Help feature to answer a few '
                  'questions and find the right services. Tap "Get Help" in the bottom navigation.',
            ),
            _section(context,
              '5. Browsing by Category',
              'The directory is organized into service categories like Food, Housing, '
                  'Healthcare, Mental Health, and more. Browse them from the home screen.',
            ),
            _section(context,
              '6. Reading a Listing',
              'Each listing includes phone number, address, hours, services offered, '
                  'description, and website. Data comes from verified federal government '
                  'records and is regularly updated.',
            ),
            _section(context,
              '7. Crisis Resources',
              'If you or someone you know is in crisis:\n\n'
                  '\u2022 Call or text 988 — Suicide & Crisis Lifeline (24/7)\n'
                  '\u2022 Text HOME to 741741 — Crisis Text Line (24/7)\n'
                  '\u2022 Call 911 for emergencies\n\n'
                  'Tap "Crisis" in the bottom navigation for more resources.',
            ),
            _section(context,
              '8. Reporting Incorrect Information',
              'If you find incorrect information in a listing, please contact us at '
                  'info@publicaid.org and we will review it.',
            ),
            _section(context,
              '9. Privacy',
              'We do not track what you search for, do not use cookies, and do not '
                  'collect any personal information. Your privacy is important to us.',
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFDCE8F5)),
            const SizedBox(height: 16),
            _linkRow(context, 'About Publicaid', 'https://publicaid.org/about'),
            _linkRow(context, 'Privacy Policy', 'https://publicaid.org/privacy'),
            _linkRow(context, 'Terms of Service', 'https://publicaid.org/terms'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: AppColors.muted(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(BuildContext context, String label, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: AppColors.muted(context)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.accent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
