import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../widgets/app_menu.dart';
import '../theme.dart';

const _topicCards = [
  _TopicCard('SNAP Benefits', 'Food', '\u{1F34E}', 'SNAP, EBT, WIC, food pantries'),
  _TopicCard('Section 8 Housing', 'Housing', '\u{1F3E0}', 'Section 8, rental help, waitlists'),
  _TopicCard('SSI/SSDI', 'Disability', '\u267F', 'SSI, SSDI, disability insurance'),
  _TopicCard('Medicaid', 'Healthcare', '\u{1F3E5}', 'Medicaid, Medicare, free clinics'),
  _TopicCard('TANF', 'Families', '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}', 'TANF, child care, WIC, CHIP'),
  _TopicCard('LIHEAP', 'Utilities', '\u{1F4A1}', 'LIHEAP, energy bills, heat help'),
];

const _topicEmojis = {
  'SNAP Benefits': '\u{1F34E}',
  'Medicaid': '\u{1F3E5}',
  'Section 8 Housing': '\u{1F3E0}',
  'WIC': '\u{1F37C}',
  'TANF': '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
  'LIHEAP': '\u{1F4A1}',
  'SSI/SSDI': '\u267F',
  'School Lunch': '\u{1F37D}\uFE0F',
};

class _TopicCard {
  final String topic;
  final String label;
  final String emoji;
  final String subtitle;

  const _TopicCard(this.topic, this.label, this.emoji, this.subtitle);
}

class BlogScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService? locationService;
  final void Function(String)? onNavigate;
  final AuthService? authService;

  const BlogScreen({super.key, required this.apiService, this.locationService, this.onNavigate, this.authService});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String? _error;
  String? _selectedTopic;
  String? _userState;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectStateAndLoad());
  }

  Future<void> _detectStateAndLoad() async {
    // Try to detect user's state from location
    final loc = widget.locationService;
    if (loc != null) {
      try {
        // If location not yet fetched, try to get it
        var pos = loc.currentLocation;
        if (pos == null && loc.permissionGranted) {
          await loc.getCurrentPosition();
          pos = loc.currentLocation;
        }
        if (pos != null) {
          final uri = Uri.parse(
              'https://publicaid.org/api/state-from-coords?lat=${pos.latitude}&lon=${pos.longitude}');
          final resp = await http.get(uri);
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            _userState = data['state'] as String?;
          }
        }
      } catch (_) {}
    }
    _loadArticles();
  }

  Future<void> _loadArticles({String? topic, int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _selectedTopic = topic;
      _page = page;
    });

    try {
      final response = await widget.apiService.getBlogArticles(
        topic: topic,
        state: _userState,
        page: page,
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _articles = data.cast<Map<String, dynamic>>();
          _total = (meta['total'] as int?) ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load articles';
      });
    }
  }

  void _onTopicTap(String topic) {
    if (_selectedTopic == topic) {
      _loadArticles(); // clear filter
    } else {
      _loadArticles(topic: topic);
    }
  }

  void _onArticleTap(Map<String, dynamic> article) {
    final slug = article['slug'] as String? ?? '';
    if (slug.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArticleDetailScreen(
          apiService: widget.apiService,
          slug: slug,
          title: article['title'] as String? ?? 'Article',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroBgOf(context),
      appBar: AppBar(
        title: const Text('Blog'),
        automaticallyImplyLeading: false,
        actions: [
          AppMenuButton(onNavigate: widget.onNavigate, authService: widget.authService),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadArticles(topic: _selectedTopic, page: _page),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Topic heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Browse by topic',
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 21,
                    color: AppColors.text(context),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            // Topic grid (2x3)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTopicCard(_topicCards[index]),
                  childCount: _topicCards.length,
                ),
              ),
            ),
            // Selected topic header
            if (_selectedTopic != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedTopic!,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _loadArticles(),
                        child: Text(
                          'All guides',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Article list heading
            if (_selectedTopic == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(
                    'Latest articles',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 21,
                      color: AppColors.text(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            // Content area
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.muted(context)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: AppColors.muted(context))),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () =>
                            _loadArticles(topic: _selectedTopic, page: _page),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_articles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No articles found.',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                      ),
                      if (_selectedTopic != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _loadArticles(),
                          child: Text(
                            'View all guides',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              color: AppColors.accent(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildArticleCard(_articles[index]),
                    ),
                    childCount: _articles.length,
                  ),
                ),
              ),
              // Total count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_total article${_total == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(_TopicCard topic) {
    final isSelected = _selectedTopic == topic.topic;
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _onTopicTap(topic.topic),
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.heroBgOf(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            border: Border.all(
              color: isSelected ? AppColors.accent(context) : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                topic.emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                topic.label,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                ),
              ),
              Text(
                topic.subtitle,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  color: AppColors.muted(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    final title = article['title'] as String? ?? '';
    final topic = article['topic'] as String? ?? '';
    final description = article['meta_description'] as String?;
    final state = article['state'] as String?;
    final publishedAt = article['published_at'] as String?;
    final emoji = _topicEmojis[topic] ?? '\u{1F4C4}';

    String dateStr = '';
    if (publishedAt != null) {
      try {
        final dt = DateTime.parse(publishedAt);
        dateStr =
            '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
      } catch (_) {}
    }

    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _onArticleTap(article),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.heroBgOf(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            border: Border.all(
              color: AppColors.cardBorderOf(context),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic emoji icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.heroBgOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 12,
                          color: AppColors.muted(context),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Tags row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.heroBgOf(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            topic,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent(context),
                            ),
                          ),
                        ),
                        if (state != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.heroBgOf(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent(context),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 10,
                              color: AppColors.muted(context),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }
}

/// Article detail screen — displays full article content.
class _ArticleDetailScreen extends StatefulWidget {
  final ApiService apiService;
  final String slug;
  final String title;

  const _ArticleDetailScreen({
    required this.apiService,
    required this.slug,
    required this.title,
  });

  @override
  State<_ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<_ArticleDetailScreen> {
  Map<String, dynamic>? _article;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final response = await widget.apiService.getBlogArticle(widget.slug);
      final data = response['data'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _article = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load article';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          _article?['title'] as String? ?? widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.muted(context)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: AppColors.muted(context))),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadArticle();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_article == null) return const SizedBox.shrink();

    final title = _article!['title'] as String? ?? '';
    final topic = _article!['topic'] as String? ?? '';
    final state = _article!['state'] as String?;
    final content = _article!['content'] as String? ?? '';
    final coverImageUrl = _article!['cover_image_url'] as String?;
    final publishedAt = _article!['published_at'] as String?;

    String dateStr = '';
    if (publishedAt != null) {
      try {
        final dt = DateTime.parse(publishedAt);
        const months = [
          '', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December',
        ];
        dateStr = '${months[dt.month]} ${dt.day}, ${dt.year}';
      } catch (_) {}
    }

    // Strip HTML tags for plain text rendering
    final plainContent = _stripHtml(content);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                coverImageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Meta row: topic tag, state tag, date
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.heroBgOf(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  topic,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent(context),
                  ),
                ),
              ),
              if (state != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tagBgOf(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Article body
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border.all(color: AppColors.cardBorderOf(context)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              plainContent,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                color: AppColors.text(context),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Strips HTML tags and decodes common entities for plain text display.
  String _stripHtml(String html) {
    // Remove HTML tags
    var text = html.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'</p>'), '\n\n');
    text = text.replaceAll(RegExp(r'</li>'), '\n');
    text = text.replaceAll(RegExp(r'</h[1-6]>'), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode common HTML entities
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&mdash;', '\u2014');
    text = text.replaceAll('&ndash;', '\u2013');
    text = text.replaceAll('&rsquo;', '\u2019');
    text = text.replaceAll('&lsquo;', '\u2018');
    text = text.replaceAll('&rdquo;', '\u201D');
    text = text.replaceAll('&ldquo;', '\u201C');
    text = text.replaceAll('&hellip;', '\u2026');
    // Collapse excessive whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
