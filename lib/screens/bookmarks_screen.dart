import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';
import 'detail_screen.dart';

class BookmarksScreen extends StatelessWidget {
  final BookmarkService bookmarkService;
  final ApiService apiService;

  const BookmarksScreen({
    super.key,
    required this.bookmarkService,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Services'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: bookmarkService,
        builder: (context, _) {
          if (bookmarkService.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = bookmarkService.bookmarks;

          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 64, color: AppColors.muted(context).withAlpha(128)),
                  const SizedBox(height: 16),
                  Text(
                    'No saved services yet',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Bookmark services to quickly find them later',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => bookmarkService.syncWithServer(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return _BookmarkCard(
                  bookmark: bookmark,
                  apiService: apiService,
                  bookmarkService: bookmarkService,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final dynamic bookmark;
  final ApiService apiService;
  final BookmarkService bookmarkService;

  const _BookmarkCard({
    required this.bookmark,
    required this.apiService,
    required this.bookmarkService,
  });

  Future<void> _launchDirections() async {
    if (bookmark.lat != null && bookmark.lng != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${bookmark.lat},${bookmark.lng}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^\d\s\+\-().]'), '');
    final uri = Uri.parse('tel:$sanitized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = bookmark.fullAddress;
    final hasAddress = address.isNotEmpty;
    final hasPhone = bookmark.phone != null && bookmark.phone!.isNotEmpty;
    final hasDescription =
        bookmark.description != null && bookmark.description!.isNotEmpty;
    final hasVisits = bookmark.checkinCount > 0;
    final hasNotes = bookmark.notes != null && bookmark.notes!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          border: Border.all(color: AppColors.cardBorderOf(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + remove button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(
                                apiService: apiService,
                                entityId: bookmark.entityId,
                                entityName: bookmark.name,
                                bookmarkService: bookmarkService,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          bookmark.name,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent(context),
                          ),
                        ),
                      ),
                      // Category
                      if (bookmark.categoryName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            bookmark.categoryName!,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: AppColors.muted(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Remove button
                IconButton(
                  icon: Icon(
                    Icons.bookmark_remove_outlined,
                    color: AppColors.muted(context),
                  ),
                  onPressed: () {
                    bookmarkService.toggleBookmark(
                      bookmark.entityId,
                      name: bookmark.name,
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22,
                ),
              ],
            ),

            // Address
            if (hasAddress) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: (bookmark.lat != null && bookmark.lng != null)
                    ? _launchDirections
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: (bookmark.lat != null && bookmark.lng != null)
                          ? AppColors.accent(context)
                          : AppColors.muted(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: (bookmark.lat != null && bookmark.lng != null)
                              ? AppColors.accent(context)
                              : AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Phone
            if (hasPhone) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _launchPhone(bookmark.phone!),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppColors.accent(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bookmark.phone!,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: AppColors.accent(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Description
            if (hasDescription) ...[
              const SizedBox(height: 10),
              Text(
                bookmark.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  color: AppColors.muted(context),
                ),
              ),
            ],

            // Visit info
            if (hasVisits) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.greenBgOf(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Visited ${bookmark.checkinCount} time${bookmark.checkinCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greenTextOf(context),
                      ),
                    ),
                  ),
                  if (bookmark.lastVisitAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Last: ${bookmark.lastVisitAt}',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 11,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Notes
            if (hasNotes) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 15,
                    color: AppColors.muted(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bookmark.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
