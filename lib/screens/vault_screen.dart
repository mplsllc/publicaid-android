import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../services/vault_service.dart';
import '../theme.dart';
import 'vault_section_screen.dart';
import 'vault_emergency_screen.dart';

class VaultScreen extends StatefulWidget {
  final VaultService vaultService;
  const VaultScreen({super.key, required this.vaultService});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  Map<String, dynamic>? _usage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cleanupTempFiles();
    WidgetsBinding.instance.addObserver(this);
    _setSecure(true);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setSecure(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.vaultService.lockVault();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecure', secure);
    } catch (_) {
      // Platform channel may not be available in all environments
    }
  }

  Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      for (final entity in tempDir.listSync()) {
        if (entity is File && entity.path.contains('vault_temp_')) {
          entity.deleteSync();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final usage = await widget.vaultService.getUsage();
      if (mounted) {
        setState(() {
          _usage = usage;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _lock() {
    widget.vaultService.lockVault();
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Settings dialog (biometric toggle)
  // ---------------------------------------------------------------------------

  Future<void> _showSettings() async {
    final canUseBiometric = await widget.vaultService.canUseBiometric();
    var biometricEnabled = await widget.vaultService.isBiometricEnabled();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vault Settings',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: canUseBiometric
                          ? AppColors.accent(ctx)
                          : AppColors.muted(ctx),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlock with fingerprint',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text(ctx),
                            ),
                          ),
                          if (!canUseBiometric)
                            Text(
                              'Biometric authentication not available',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 13,
                                color: AppColors.muted(ctx),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch(
                      value: biometricEnabled,
                      activeColor: AppColors.accent(ctx),
                      onChanged: canUseBiometric
                          ? (value) async {
                              try {
                                if (value) {
                                  await widget.vaultService.enableBiometric();
                                } else {
                                  await widget.vaultService.disableBiometric();
                                }
                                setSheetState(
                                    () => biometricEnabled = value);
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Could not update biometric setting'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAB add menu
  // ---------------------------------------------------------------------------

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.badge_outlined,
                  color: AppColors.accent(context)),
              title: Text('Identity Documents',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToSection('identity', 'Identity Documents',
                    autoPickFile: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.health_and_safety_outlined,
                  color: AppColors.accent(context)),
              title: Text('Insurance Cards',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToSection('insurance', 'Insurance Cards',
                    autoPickFile: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined,
                  color: AppColors.accent(context)),
              title: Text('General Documents',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToSection('general', 'General Documents',
                    autoPickFile: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToSection(String section, String title,
      {bool autoPickFile = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultSectionScreen(
          vaultService: widget.vaultService,
          section: section,
          sectionTitle: title,
          autoPickFile: autoPickFile,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {}); // refresh counts
        _loadData(); // refresh usage
      }
    });
  }

  void _navigateToEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultEmergencyScreen(
          vaultService: widget.vaultService,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _showSettings,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outlined),
            tooltip: 'Lock vault',
            onPressed: _lock,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildSectionList()),
                if (_usage != null) _buildUsageBar(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: AppColors.accent(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSectionList() {
    final sections = [
      _SectionInfo(
        icon: Icons.badge_outlined,
        title: 'Identity Documents',
        section: 'identity',
      ),
      _SectionInfo(
        icon: Icons.health_and_safety_outlined,
        title: 'Insurance Cards',
        section: 'insurance',
      ),
      _SectionInfo(
        icon: Icons.folder_outlined,
        title: 'General Documents',
        section: 'general',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File sections
        for (final s in sections) ...[
          _buildSectionCard(
            icon: s.icon,
            title: s.title,
            trailing: _buildItemCount(
              widget.vaultService.getDocumentsBySection(s.section).length,
            ),
            onTap: () => _navigateToSection(s.section, s.title),
          ),
          const SizedBox(height: 8),
        ],
        // Emergency section
        _buildSectionCard(
          icon: Icons.emergency_outlined,
          title: 'Emergency Info',
          trailing: _buildEmergencyDot(),
          onTap: _navigateToEmergency,
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent(context), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              trailing,
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: AppColors.muted(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCount(int count) {
    return Text(
      '$count',
      style: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.muted(context),
      ),
    );
  }

  Widget _buildEmergencyDot() {
    final hasData = widget.vaultService.hasEmergencyData();
    return Text(
      hasData ? '\u25CF' : '\u25CB',
      style: TextStyle(
        fontSize: 14,
        color: hasData
            ? AppColors.greenTextOf(context)
            : AppColors.muted(context),
      ),
    );
  }

  Widget _buildUsageBar() {
    final used = _usage?['used'] as int? ?? 0;
    final limit = _usage?['limit'] as int? ?? (1024 * 1024 * 1024); // 1 GB
    final fraction = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.cardBorderOf(context)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Using ${_formatBytes(used)} of 1 GB',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  color: AppColors.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.cardBorderOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.accent(context),
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper class for section definitions
// ---------------------------------------------------------------------------

class _SectionInfo {
  final IconData icon;
  final String title;
  final String section;

  const _SectionInfo({
    required this.icon,
    required this.title,
    required this.section,
  });
}
