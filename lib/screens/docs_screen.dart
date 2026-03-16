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
            const Text(
              'How to Use Publicaid',
              style: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 26,
                color: AppColors.navyBlue,
              ),
            ),
            const SizedBox(height: 20),
            _section(
              '1. Finding Services',
              'Search by service type, organization name, or general need. '
                  'Results are ranked by relevance and match against organization names, '
                  'descriptions, services offered, and categories.',
            ),
            _section(
              '2. Filtering Results',
              'Filter by state, category, city, language, payment type '
                  '(Medicaid, sliding scale, free), population served '
                  '(veterans, youth, seniors), and accessibility features.',
            ),
            _section(
              '3. Using Your Location',
              'Enable location services or enter a ZIP code to find nearby results. '
                  'Your location is used for that one search and immediately discarded. '
                  'It is never saved, never logged, and never tied to what you searched for.',
            ),
            _section(
              '4. The Guide',
              'Not sure what to search for? Use the Guided Help feature to answer a few '
                  'questions and find the right services. Tap "Get Help" in the bottom navigation.',
            ),
            _section(
              '5. Browsing by Category',
              'The directory is organized into service categories like Food, Housing, '
                  'Healthcare, Mental Health, and more. Browse them from the home screen.',
            ),
            _section(
              '6. Reading a Listing',
              'Each listing includes phone number, address, hours, services offered, '
                  'description, and website. Data comes from verified federal government '
                  'records and is regularly updated.',
            ),
            _section(
              '7. Crisis Resources',
              'If you or someone you know is in crisis:\n\n'
                  '\u2022 Call or text 988 — Suicide & Crisis Lifeline (24/7)\n'
                  '\u2022 Text HOME to 741741 — Crisis Text Line (24/7)\n'
                  '\u2022 Call 911 for emergencies\n\n'
                  'Tap "Crisis" in the bottom navigation for more resources.',
            ),
            _section(
              '8. Reporting Incorrect Information',
              'If you find incorrect information in a listing, please contact us at '
                  'info@publicaid.org and we will review it.',
            ),
            _section(
              '9. Privacy',
              'We do not track what you search for, do not use cookies, and do not '
                  'collect any personal information. Your privacy is important to us.',
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFDCE8F5)),
            const SizedBox(height: 16),
            _linkRow('About Publicaid', 'https://publicaid.org/about'),
            _linkRow('Privacy Policy', 'https://publicaid.org/privacy'),
            _linkRow('Terms of Service', 'https://publicaid.org/terms'),
            const SizedBox(height: 32),
          ],
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
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: AppColors.grayText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(String label, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 16, color: AppColors.mediumGray),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.brightBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
