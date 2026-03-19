import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
import '../services/location_service.dart';
import '../services/plan_service.dart';
import '../theme.dart';
import 'search_screen.dart';

class DetailScreen extends StatefulWidget {
  final ApiService apiService;
  final String entityId;
  final String entityName;
  final BookmarkService? bookmarkService;
  final AuthService? authService;
  final PlanService? planService;
  final LocationService? locationService;

  const DetailScreen({
    super.key,
    required this.apiService,
    required this.entityId,
    required this.entityName,
    this.bookmarkService,
    this.authService,
    this.planService,
    this.locationService,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Entity? _entity;
  List<EntityService> _services = [];
  List<EntityHours> _hours = [];
  bool _loading = true;
  String? _error;
  bool _isSupporting = false;
  bool _savingSupport = false;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int _retryCount = 0;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load in parallel for speed
      final results = await Future.wait([
        widget.apiService.getEntity(widget.entityId),
        widget.apiService.getEntityServices(widget.entityId),
        widget.apiService.getEntityHours(widget.entityId),
      ]);

      if (mounted) {
        setState(() {
          _entity = results[0] as Entity;
          _services = results[1] as List<EntityService>;
          _hours = results[2] as List<EntityHours>;
          _loading = false;
          _retryCount = 0;
        });
      }
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('DetailScreen error loading ${widget.entityId}: $e');
      // Don't retry on rate limit — wait longer
      if (e.statusCode == 429) {
        if (mounted) {
          setState(() {
            _error = 'Too many requests. Please wait a moment and try again.';
            _loading = false;
          });
        }
        return;
      }
      // Auto-retry once on other errors
      if (_retryCount < 1 && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _loadData();
        return;
      }
      if (mounted) {
        setState(() {
          _error = 'Could not load details. Tap to retry.';
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DetailScreen error loading ${widget.entityId}: $e');
      if (_retryCount < 1 && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _loadData();
        return;
      }
      if (mounted) {
        setState(() {
          _error = 'Could not load details. Tap to retry.';
          _loading = false;
        });
      }
    }
  }

  void _toggleBookmark() {
    if (_entity == null || widget.bookmarkService == null) return;
    final e = _entity!;
    widget.bookmarkService!.toggleBookmark(
      e.id,
      name: e.name,
      slug: e.slug,
      city: e.city,
      state: e.state,
      phone: e.phone,
      categoryName: e.categories.isNotEmpty ? e.categories.first.name : null,
      addressLine1: e.addressLine1,
      addressLine2: e.addressLine2,
      zip: e.zip,
      description: e.description,
      website: e.website,
      lat: e.lat,
      lng: e.lng,
    );
    setState(() {}); // Rebuild to reflect bookmark state
  }

  Future<void> _toggleSupport() async {
    if (widget.authService == null || !widget.authService!.isLoggedIn) return;
    setState(() => _savingSupport = true);
    try {
      final result = await widget.apiService.toggleSupport(widget.entityId);
      if (mounted) setState(() => _isSupporting = result);
    } catch (_) {}
    if (mounted) setState(() => _savingSupport = false);
  }

  Future<void> _addCheckin() async {
    if (widget.authService == null || !widget.authService!.isLoggedIn) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log a Visit'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Visit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _checkingIn = true);
    try {
      final note = noteController.text.trim();
      await widget.apiService.addCheckin(
        widget.entityId,
        note: note.isNotEmpty ? note : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Visit logged!'),
            backgroundColor: AppColors.greenTextOf(context),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log visit. Try again.')),
        );
      }
    }
    if (mounted) setState(() => _checkingIn = false);
    noteController.dispose();
  }

  void _openDirections() {
    if (_entity?.lat == null || _entity?.lng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_entity!.lat},${_entity!.lng}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _shareEntity() {
    if (_entity == null) return;
    Share.share('${_entity!.name}\nhttps://publicaid.org/${_entity!.slug}');
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

  @override
  Widget build(BuildContext context) {
    final isBookmarked = widget.bookmarkService?.isBookmarked(widget.entityId) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entityName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.bookmarkService != null)
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              onPressed: _toggleBookmark,
            ),
        ],
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _entity == null
                  ? const Center(child: Text('Entity not found'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final e = _entity!;
    final isBookmarked = widget.bookmarkService?.isBookmarked(widget.entityId) ?? false;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Entity name + category tags ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text(context),
                  ),
                ),
                if (e.categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: e.categories
                        .map((c) => GestureDetector(
                              onTap: () {
                                if (widget.locationService != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SearchScreen(
                                        apiService: widget.apiService,
                                        locationService: widget.locationService!,
                                        authService: widget.authService,
                                        bookmarkService: widget.bookmarkService,
                                        planService: widget.planService,
                                        initialCategory: c.slug,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.tagBgOf(context),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accent(context),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Contact info card (phone, intake, address, website) ---
          _buildContactInfoCard(e),

          // --- Action buttons ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (e.lat != null && e.lng != null)
                  ElevatedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Get Directions'),
                  ),
                OutlinedButton.icon(
                  onPressed: _shareEntity,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: isBookmarked ? AppColors.accent(context) : null,
                  ),
                  label: Text(isBookmarked ? 'Saved' : 'Save'),
                  style: isBookmarked
                      ? OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.accent(context)),
                          foregroundColor: AppColors.accent(context),
                        )
                      : null,
                ),
                if (widget.authService?.isLoggedIn == true) ...[
                  OutlinedButton.icon(
                    onPressed: _savingSupport ? null : _toggleSupport,
                    icon: Icon(
                      _isSupporting ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _isSupporting ? Colors.red : null,
                    ),
                    label: Text(_isSupporting ? 'Supporting' : 'I Support'),
                    style: _isSupporting
                        ? OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),

          // --- About ---
          if (e.description != null && e.description!.isNotEmpty) ...[
            _sectionHeader('ABOUT'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                e.description!,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  color: AppColors.text(context),
                  height: 1.6,
                ),
              ),
            ),
          ],

          // --- Eligibility (populations, age groups) ---
          if (e.populationsServed.isNotEmpty || e.ageGroups.isNotEmpty) ...[
            _sectionHeader('ELIGIBILITY'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: [
                  ...e.ageGroups.map((a) => _infoChip(a)),
                  ...e.populationsServed.map((p) => _infoChip(p)),
                  ...e.paymentTypes.map((p) => _infoChip(p)),
                ],
              ),
            ),
          ],

          // --- Languages ---
          if (e.languages.isNotEmpty) ...[
            _sectionHeader('LANGUAGES'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: e.languages.map((l) => _infoChip(l)).toList(),
              ),
            ),
          ],

          // --- Service Settings ---
          if (_services.isNotEmpty) ...[
            _sectionHeader('SERVICE SETTINGS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: _services.map((s) => _infoChip(s.name)).toList(),
              ),
            ),
          ],

          // --- Hours ---
          if (_hours.isNotEmpty) ...[
            _sectionHeader('HOURS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _hours
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(h.dayName,
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text(context),
                                  )),
                              Text(h.hoursText,
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 14,
                                    color: h.closed
                                        ? Colors.red
                                        : AppColors.muted(context),
                                  )),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          // --- Accessibility ---
          if (e.accessibility.isNotEmpty) ...[
            _sectionHeader('ACCESSIBILITY'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: e.accessibility.map((a) => _infoChip(a)).toList(),
              ),
            ),
          ],

          // --- Data quality footer ---
          if (e.dataQuality != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildDataQualityFooter(e.dataQuality!),
            ),
          ],

          // --- Logged-in actions (visit, plan) ---
          if (widget.authService?.isLoggedIn == true) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checkingIn ? null : _addCheckin,
                      icon: Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.greenTextOf(context)),
                      label: Text(_checkingIn ? 'Logging...' : 'Log a Visit'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.greenTextOf(context)),
                        foregroundColor: AppColors.greenTextOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (widget.planService == null) return;
                        final e = _entity!;
                        if (widget.planService!.isInPlan(e.id)) return;
                        widget.planService!.addToPlan(e.id,
                            entityName: e.name,
                            city: e.city,
                            state: e.state,
                            phone: e.phone,
                            addressLine1: e.addressLine1);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to your plan!')));
                        setState(() {});
                      },
                      icon: Icon(
                          widget.planService?.isInPlan(widget.entityId) == true
                              ? Icons.check
                              : Icons.add_task,
                          size: 18),
                      label: Text(
                          widget.planService?.isInPlan(widget.entityId) == true
                              ? 'In Plan'
                              : 'Add to Plan'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.muted(context),
        ),
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tagBgOf(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 13,
          color: AppColors.text(context),
        ),
      ),
    );
  }

  /// Contact info card matching the website layout: labeled rows for phone,
  /// intake, address, website — each tappable.
  Widget _buildContactInfoCard(Entity e) {
    final hasAny = (e.phone != null && e.phone!.isNotEmpty) ||
        (e.intakePhone != null && e.intakePhone!.isNotEmpty) ||
        (e.fullAddress.isNotEmpty) ||
        (e.website != null && e.website!.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.phone != null && e.phone!.isNotEmpty)
            _contactInfoRow('PHONE', e.phone!, onTap: () => _callPhone(e.phone!)),
          if (e.intakePhone != null && e.intakePhone!.isNotEmpty)
            _contactInfoRow('INTAKE LINE', e.intakePhone!,
                onTap: () => _callPhone(e.intakePhone!)),
          if (e.fullAddress.isNotEmpty)
            _contactInfoRow('ADDRESS', e.fullAddress,
                onTap: (e.lat != null && e.lng != null) ? _openDirections : null),
          if (e.website != null && e.website!.isNotEmpty)
            _contactInfoRow('WEBSITE', e.website!,
                onTap: () => _openWebsite(e.website!), isUrl: true),
        ],
      ),
    );
  }

  Widget _contactInfoRow(String label, String value,
      {VoidCallback? onTap, bool isUrl = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: isUrl ? 14 : 16,
                fontWeight: isUrl ? FontWeight.w400 : FontWeight.w600,
                color: onTap != null
                    ? AppColors.accent(context)
                    : AppColors.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDataQualityFooter(DataQuality dq) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dq.isVerified ? AppColors.greenBgOf(context) : AppColors.heroBgOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dq.isVerified
              ? AppColors.greenTextOf(context).withAlpha(50)
              : AppColors.cardBorderOf(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            dq.isVerified ? Icons.verified : Icons.info_outline,
            size: 18,
            color: dq.isVerified ? AppColors.greenTextOf(context) : AppColors.muted(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dq.isVerified ? 'Verified Information' : 'Data Quality',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dq.isVerified
                        ? AppColors.greenTextOf(context)
                        : AppColors.text(context),
                  ),
                ),
                if (dq.lastVerifiedAt != null)
                  Text(
                    'Last verified: ${dq.lastVerifiedAt}',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                if (dq.sourceCount != null)
                  Text(
                    '${dq.sourceCount} data source${dq.sourceCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
