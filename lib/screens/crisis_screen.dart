import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Red 988 hero
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 32,
                bottom: 32,
                left: 20,
                right: 20,
              ),
              color: const Color(0xFFDC2626),
              child: Column(
                children: [
                  const Text(
                    'If you are in danger right now, call 911.',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:988')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Call or text 988',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Suicide & Crisis Lifeline — free, confidential, 24/7',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      color: Colors.white.withAlpha(200),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Secondary options
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get help right now',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 24,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CrisisOption(
                    emoji: '\u{1F4AC}',
                    title: 'Text 988',
                    subtitle:
                        "If you can't talk — text is available 24/7",
                    onTap: () => launchUrl(Uri.parse('sms:988')),
                  ),
                  const SizedBox(height: 12),
                  _CrisisOption(
                    emoji: '\u{1F5A5}\uFE0F',
                    title: 'Chat online with 988',
                    subtitle: '988lifeline.org — free, confidential',
                    onTap: () => launchUrl(
                        Uri.parse('https://chat.988lifeline.org'),
                        mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: 12),
                  _CrisisOption(
                    emoji: '\u{1F4F1}',
                    title: 'Text HOME to 741741',
                    subtitle: 'Crisis Text Line — free, 24/7',
                    onTap: () =>
                        launchUrl(Uri.parse('sms:741741?body=HELLO')),
                  ),
                  const SizedBox(height: 12),
                  _CrisisOption(
                    emoji: '\u{1F396}\uFE0F',
                    title: 'Veterans Crisis Line',
                    subtitle:
                        '1-800-273-8255, press 1 — or text 838255',
                    onTap: () =>
                        launchUrl(Uri.parse('tel:18002738255')),
                  ),
                  const SizedBox(height: 12),
                  _CrisisOption(
                    emoji: '\u{1F3F3}\uFE0F\u200D\u{1F308}',
                    title: 'The Trevor Project',
                    subtitle:
                        'For LGBTQ+ youth — 1-866-488-7386, 24/7',
                    onTap: () =>
                        launchUrl(Uri.parse('tel:18664887386')),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.only(top: 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFDCE8F5)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Looking for local mental health services near you?',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 13,
                            color: AppColors.grayText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            // Pop back and they can search
                          },
                          child: const Text(
                            'Find mental health resources near me \u2192',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              color: AppColors.brightBlue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrisisOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CrisisOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDCE8F5), width: 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D3B6E).withAlpha(13),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
