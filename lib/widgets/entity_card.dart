import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/entity.dart';
import '../theme.dart';

class EntityCard extends StatelessWidget {
  final Entity entity;
  final VoidCallback onTap;
  final VoidCallback? onBookmark;
  final bool isBookmarked;

  const EntityCard({
    super.key,
    required this.entity,
    required this.onTap,
    this.onBookmark,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkCardBorder : AppColors.cardBorder;
    final accent = isDark ? AppColors.lightBlue : AppColors.brightBlue;
    final muted = isDark ? AppColors.darkGrayText : AppColors.grayText;
    final titleColor = isDark ? AppColors.lightBlue : AppColors.brightBlue;
    final linkColor = isDark ? AppColors.lightBlue : AppColors.navyBlue;
    final tagBg = isDark ? AppColors.darkTagBg : AppColors.tagBg;
    final greenBg = isDark ? AppColors.darkGreenBg : AppColors.greenBg;
    final greenText = isDark ? AppColors.lightGreen : AppColors.greenAccent;
    final verifiedColor = isDark ? AppColors.lightBlue : const Color(0xFF4A90D9);
    final inputBorder = isDark ? AppColors.darkInputBorder : AppColors.inputBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name + verified + distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      entity.name,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    if (entity.dataQuality?.isVerified == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: verifiedColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: verifiedColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (entity.distanceText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: greenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entity.distanceText!,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: greenText,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Row 2: Category tags
          if (entity.categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: entity.categories.take(3).map((cat) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Row 3: Description
          if (entity.description != null &&
              entity.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entity.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: muted,
              ),
            ),
          ],

          // Row 4: Address / Phone / Website
          if (entity.fullAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entity.fullAddress.replaceAll('\n', ', '),
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (entity.phone != null && entity.phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _callPhone(entity.phone!),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 16, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    entity.phone!,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (entity.website != null && entity.website!.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openWebsite(entity.website!),
              child: Row(
                children: [
                  Icon(Icons.language, size: 16, color: linkColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatDomain(entity.website!),
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: linkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '\u2197',
                    style: TextStyle(
                      fontSize: 13,
                      color: linkColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Divider before actions
          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),

          // Row 5: Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // View Details
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    textStyle: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('View Details >'),
                ),
              ),

              // Call
              if (entity.phone != null && entity.phone!.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () => _callPhone(entity.phone!),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenBg,
                      foregroundColor: greenText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      textStyle: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Website
              if (entity.website != null && entity.website!.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => _openWebsite(entity.website!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: linkColor,
                      side: BorderSide(color: inputBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      textStyle: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Website \u2197'),
                  ),
                ),

              // Save
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 14,
                  ),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: muted,
                    side: BorderSide(color: inputBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    textStyle: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  String _formatDomain(String url) {
    var domain = url.replaceAll(RegExp(r'^https?://'), '');
    domain = domain.replaceAll(RegExp(r'^www\.'), '');
    domain = domain.split('/').first;
    return domain;
  }

  void _callPhone(String phone) {
    final sanitized = phone.replaceAll(RegExp(r'[^\d\s\+\-().]'), '');
    if (sanitized.isNotEmpty) {
      launchUrl(Uri.parse('tel:$sanitized'));
    }
  }

  void _openWebsite(String url) {
    final parsed = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (parsed != null && ['http', 'https'].contains(parsed.scheme)) {
      launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }
}
