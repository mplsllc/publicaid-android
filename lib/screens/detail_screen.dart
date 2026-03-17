import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
import '../services/plan_service.dart';
import '../theme.dart';

class DetailScreen extends StatefulWidget {
  final ApiService apiService;
  final String entityId;
  final String entityName;
  final BookmarkService? bookmarkService;
  final AuthService? authService;
  final PlanService? planService;

  const DetailScreen({
    super.key,
    required this.apiService,
    required this.entityId,
    required this.entityName,
    this.bookmarkService,
    this.authService,
    this.planService,
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
      // Load sequentially to avoid rate limiting
      final entity = await widget.apiService.getEntity(widget.entityId);
      final services = await widget.apiService.getEntityServices(widget.entityId);
      final hours = await widget.apiService.getEntityHours(widget.entityId);

      if (mounted) {
        setState(() {
          _entity = entity;
          _services = services;
          _hours = hours;
          _loading = false;
          _retryCount = 0;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DetailScreen error loading ${widget.entityId}: $e');
      // Auto-retry up to 3 times with backoff
      if (_retryCount < 3 && mounted) {
        _retryCount++;
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
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
          const SnackBar(
            content: Text('Visit logged!'),
            backgroundColor: AppColors.greenAccent,
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
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.mediumGray),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.grayText)),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.lat != null && e.lng != null)
                ElevatedButton.icon(
                  onPressed: _openDirections,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                ),
              OutlinedButton.icon(
                onPressed: _shareEntity,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
              if (widget.authService?.isLoggedIn == true) ...[
                OutlinedButton.icon(
                  onPressed: _toggleBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: isBookmarked ? AppColors.brightBlue : null,
                  ),
                  label: Text(isBookmarked ? 'Saved' : 'Save'),
                  style: isBookmarked
                      ? OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.brightBlue),
                          foregroundColor: AppColors.brightBlue,
                        )
                      : null,
                ),
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
                OutlinedButton.icon(
                  onPressed: _checkingIn ? null : _addCheckin,
                  icon: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.greenAccent,
                  ),
                  label: Text(_checkingIn ? 'Logging...' : 'I Visited'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.greenAccent),
                    foregroundColor: AppColors.greenAccent,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (widget.planService == null) return;
                    final e = _entity!;
                    if (widget.planService!.isInPlan(e.id)) return;
                    widget.planService!.addToPlan(e.id, entityName: e.name, city: e.city, state: e.state, phone: e.phone, addressLine1: e.addressLine1);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to your plan!')));
                  },
                  icon: Icon(widget.planService?.isInPlan(widget.entityId) == true ? Icons.check : Icons.add_task, size: 18),
                  label: Text(widget.planService?.isInPlan(widget.entityId) == true ? 'In Plan' : 'Add to Plan'),
                ),
              ],
            ],
          ),

          // Description
          if (e.description != null && e.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('About',
                style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 20,
                    color: AppColors.navyBlue)),
            const SizedBox(height: 8),
            Text(
              e.description!,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.navyBlue,
                height: 1.5,
              ),
            ),
          ],

          // Contact card
          const SizedBox(height: 20),
          _buildContactCard(e),

          // Address
          if (e.fullAddress.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('Address', [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.grayText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.fullAddress,
                      style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: AppColors.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ],

          // Hours
          if (_hours.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('Hours', [
              ..._hours.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          h.dayName,
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        Text(
                          h.hoursText,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 14,
                            color: h.closed ? Colors.red : AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  )),
            ]),
          ],

          // Services
          if (_services.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('Services', [
              ..._services.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: AppColors.greenAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navyBlue,
                                ),
                              ),
                              if (s.description != null &&
                                  s.description!.isNotEmpty)
                                Text(
                                  s.description!,
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
                  )),
            ]),
          ],

          // Category tags
          if (e.categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('Categories', [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: e.categories
                    .map((c) => Chip(label: Text(c.name)))
                    .toList(),
              ),
            ]),
          ],

          // Details section (languages, payment, populations, accessibility)
          if (_hasDetailInfo(e)) ...[
            const SizedBox(height: 20),
            _buildDetailsSection(e),
          ],

          // Data quality footer
          if (e.dataQuality != null) ...[
            const SizedBox(height: 20),
            _buildDataQualityFooter(e.dataQuality!),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildContactCard(Entity e) {
    final hasContact = (e.phone != null && e.phone!.isNotEmpty) ||
        (e.intakePhone != null && e.intakePhone!.isNotEmpty) ||
        (e.website != null && e.website!.isNotEmpty);

    if (!hasContact) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact',
                style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 18,
                    color: AppColors.navyBlue)),
            const SizedBox(height: 12),
            if (e.phone != null && e.phone!.isNotEmpty)
              _contactRow(Icons.phone, 'Phone', e.phone!,
                  onTap: () => _callPhone(e.phone!)),
            if (e.intakePhone != null && e.intakePhone!.isNotEmpty)
              _contactRow(Icons.phone_in_talk, 'Intake', e.intakePhone!,
                  onTap: () => _callPhone(e.intakePhone!)),
            if (e.website != null && e.website!.isNotEmpty)
              _contactRow(Icons.language, 'Website', e.website!,
                  onTap: () => _openWebsite(e.website!)),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brightBlue),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 12,
                        color: AppColors.grayText)),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brightBlue,
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 18,
                    color: AppColors.navyBlue)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  bool _hasDetailInfo(Entity e) {
    return e.languages.isNotEmpty ||
        e.paymentTypes.isNotEmpty ||
        e.populationsServed.isNotEmpty ||
        e.accessibility.isNotEmpty ||
        e.ageGroups.isNotEmpty;
  }

  Widget _buildDetailsSection(Entity e) {
    return _buildSection('Details', [
      if (e.languages.isNotEmpty) _detailRow('Languages', e.languages.join(', ')),
      if (e.paymentTypes.isNotEmpty)
        _detailRow('Payment Types', e.paymentTypes.join(', ')),
      if (e.populationsServed.isNotEmpty)
        _detailRow('Populations Served', e.populationsServed.join(', ')),
      if (e.ageGroups.isNotEmpty) _detailRow('Age Groups', e.ageGroups.join(', ')),
      if (e.accessibility.isNotEmpty)
        _detailRow('Accessibility', e.accessibility.join(', ')),
    ]);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: AppColors.navyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityFooter(DataQuality dq) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dq.isVerified ? AppColors.greenBg : AppColors.heroBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dq.isVerified
              ? AppColors.greenAccent.withAlpha(50)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            dq.isVerified ? Icons.verified : Icons.info_outline,
            size: 18,
            color: dq.isVerified ? AppColors.greenAccent : AppColors.grayText,
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
                        ? AppColors.greenAccent
                        : AppColors.navyBlue,
                  ),
                ),
                if (dq.lastVerifiedAt != null)
                  Text(
                    'Last verified: ${dq.lastVerifiedAt}',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.grayText,
                    ),
                  ),
                if (dq.sourceCount != null)
                  Text(
                    '${dq.sourceCount} data source${dq.sourceCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.grayText,
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
