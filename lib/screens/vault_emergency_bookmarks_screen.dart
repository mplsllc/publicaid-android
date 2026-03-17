import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/vault_service.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';

class VaultEmergencyBookmarksScreen extends StatefulWidget {
  final VaultService vaultService;
  final BookmarkService bookmarkService;

  const VaultEmergencyBookmarksScreen({
    super.key,
    required this.vaultService,
    required this.bookmarkService,
  });

  @override
  State<VaultEmergencyBookmarksScreen> createState() =>
      _VaultEmergencyBookmarksScreenState();
}

class _VaultEmergencyBookmarksScreenState
    extends State<VaultEmergencyBookmarksScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  List<Map<String, dynamic>> _snapshot = [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _setSecure(true);
    _loadSnapshot();
  }

  @override
  void dispose() {
    _setSecure(false);
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecure', secure);
    } catch (_) {}
  }

  void _loadSnapshot() {
    setState(() {
      _snapshot = widget.vaultService.getEmergencyBookmarks();
    });
  }

  // ---------------------------------------------------------------------------
  // Sync from BookmarkService
  // ---------------------------------------------------------------------------

  Future<void> _updateFromBookmarks() async {
    setState(() => _syncing = true);

    try {
      final bookmarks = widget.bookmarkService.bookmarks;
      final items = bookmarks.map((b) {
        return <String, dynamic>{
          'name': b.name,
          'phone': b.phone ?? '',
          'address': b.fullAddress,
        };
      }).toList();

      await widget.vaultService.saveEmergencyBookmarks(items);
      _loadSnapshot();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} service${items.length == 1 ? '' : 's'} updated'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync bookmarks')),
        );
      }
    }

    if (mounted) setState(() => _syncing = false);
  }

  // ---------------------------------------------------------------------------
  // Call
  // ---------------------------------------------------------------------------

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasBookmarks = widget.bookmarkService.bookmarks.isNotEmpty;
    final isEmpty = _snapshot.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Services'),
      ),
      body: Column(
        children: [
          // Sync button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _updateFromBookmarks,
                icon: _syncing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: const Text('Update from Saved Services'),
              ),
            ),
          ),

          // Content
          Expanded(
            child: isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_outlined,
                            size: 64,
                            color: AppColors.muted(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasBookmarks
                                ? 'Not synced yet'
                                : 'No saved services',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasBookmarks
                                ? 'Tap "Update from Saved Services" to sync your bookmarks here for emergency access'
                                : 'Save services in the app, then sync them here for emergency access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              color: AppColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _snapshot.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildServiceCard(_snapshot[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final name = service['name'] as String? ?? 'Unknown';
    final phone = service['phone'] as String? ?? '';
    final address = service['address'] as String? ?? '';

    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _callPhone(phone),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppColors.accent(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: AppColors.accent(context),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.muted(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: AppColors.muted(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
