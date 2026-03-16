import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'categories_screen.dart';
import 'search_screen.dart';

class _GuideOption {
  final String emoji;
  final String title;
  final String subtitle;
  final String value;

  const _GuideOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
  });
}

const _guideOptions = [
  _GuideOption(
    emoji: '\u{1F34E}',
    title: 'Food',
    subtitle: 'Groceries, meals, food pantries',
    value: 'food',
  ),
  _GuideOption(
    emoji: '\u{1F3E0}',
    title: 'A place to stay',
    subtitle: 'Shelters and housing help',
    value: 'housing',
  ),
  _GuideOption(
    emoji: '\u{1F9E0}',
    title: 'Mental health',
    subtitle: 'Counseling and therapy',
    value: 'mental-health',
  ),
  _GuideOption(
    emoji: '\u{1F48A}',
    title: 'Help with drinking or drugs',
    subtitle: 'Detox and recovery',
    value: 'substance-use',
  ),
  _GuideOption(
    emoji: '\u{2764}\u{FE0F}',
    title: 'Healthcare',
    subtitle: 'Free clinics and doctors',
    value: 'healthcare',
  ),
  _GuideOption(
    emoji: '\u{2795}',
    title: 'Something else',
    subtitle: 'All other kinds of help',
    value: 'other',
  ),
];

class GuideScreen extends StatelessWidget {
  final ApiService apiService;
  final LocationService locationService;

  const GuideScreen({
    super.key,
    required this.apiService,
    required this.locationService,
  });

  void _onOptionTap(BuildContext context, _GuideOption option) {
    if (option.value == 'other') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriesScreen(
            apiService: apiService,
            locationService: locationService,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(
            apiService: apiService,
            locationService: locationService,
            initialCategory: option.value,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text(
          'Guided Help',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                'Step 1 of 2',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.brightBlue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          const Text(
            'What kind of help do you need?',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 16),

          // Option cards
          ..._guideOptions.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GuideOptionCard(
                  option: option,
                  onTap: () => _onOptionTap(context, option),
                ),
              )),

          // Documentation link
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () {
                // Could open docs URL in browser in the future
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: AppColors.grayText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Documentation & resources',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GuideOptionCard extends StatelessWidget {
  final _GuideOption option;
  final VoidCallback onTap;

  const _GuideOptionCard({
    required this.option,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0D3B6E),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brightBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                option.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
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
