import 'package:flutter/material.dart';
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
                      size: 64, color: AppColors.mediumGray.withAlpha(128)),
                  const SizedBox(height: 16),
                  const Text(
                    'No saved services yet',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Bookmark services to quickly find them later',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: AppColors.grayText,
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
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.heroBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bookmark,
                          color: AppColors.brightBlue, size: 22),
                    ),
                    title: Text(
                      bookmark.name,
                      style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brightBlue,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bookmark.categoryName != null)
                          Text(
                            bookmark.categoryName!,
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: AppColors.grayText,
                            ),
                          ),
                        if (bookmark.city != null || bookmark.state != null)
                          Text(
                            [bookmark.city, bookmark.state]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(', '),
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: AppColors.grayText,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove_outlined,
                          color: AppColors.mediumGray),
                      onPressed: () {
                        bookmarkService.toggleBookmark(
                          bookmark.entityId,
                          name: bookmark.name,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
