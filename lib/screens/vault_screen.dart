import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import 'vault_note_screen.dart';

class VaultScreen extends StatefulWidget {
  final VaultService vaultService;
  const VaultScreen({super.key, required this.vaultService});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _usage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSecure(true);
    _loadDocuments();
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

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    try {
      final docs = widget.vaultService.getDocuments();
      final usage = await widget.vaultService.getUsage();
      if (mounted) {
        setState(() {
          _documents = docs;
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

  Future<void> _deleteDocument(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'This document will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.vaultService.deleteDocument(id);
      _loadDocuments();
    }
  }

  void _lock() {
    widget.vaultService.lockVault();
    Navigator.pop(context);
  }

  void _onTapDocument(Map<String, dynamic> doc) {
    final type = doc['type'] as String?;
    if (type == 'note') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VaultNoteScreen(
            vaultService: widget.vaultService,
            existingNote: doc,
          ),
        ),
      ).then((_) => _loadDocuments());
    } else {
      _viewFile(doc);
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.note_add_outlined,
                  color: AppColors.accent(context)),
              title: Text('Add Note',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VaultNoteScreen(
                      vaultService: widget.vaultService,
                    ),
                  ),
                ).then((_) => _loadDocuments());
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.accent(context)),
              title: Text('Take Photo',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.accent(context)),
              title: Text('Choose from Gallery',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final title = picked.name.isNotEmpty ? picked.name : 'Photo ${DateTime.now().toIso8601String().substring(0, 10)}';

      setState(() => _loading = true);
      await widget.vaultService.addFile(title, bytes);
      _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved'), backgroundColor: AppColors.greenAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save photo')),
        );
      }
    }
  }

  Future<void> _viewFile(Map<String, dynamic> doc) async {
    final id = doc['id'] as String;
    setState(() => _loading = true);

    try {
      final decryptedBytes = await widget.vaultService.downloadFile(id);
      setState(() => _loading = false);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VaultFileViewer(
            title: doc['title'] as String? ?? 'File',
            bytes: decryptedBytes,
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
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
                Expanded(
                  child: _documents.isEmpty
                      ? _buildEmptyState()
                      : _buildDocumentList(),
                ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: AppColors.muted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a note or photo',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: AppColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return _buildDocumentCard(doc);
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final type = doc['type'] as String?;
    final title = doc['title'] as String? ?? 'Untitled';
    final isNote = type == 'note';

    String subtitle;
    if (isNote) {
      final content = doc['content'] as String? ?? '';
      subtitle = content.split('\n').first;
      if (subtitle.length > 80) {
        subtitle = '${subtitle.substring(0, 80)}...';
      }
      if (subtitle.isEmpty) subtitle = 'Empty note';
    } else {
      final size = doc['size'] as int? ?? 0;
      subtitle = _formatBytes(size);
    }

    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTapDocument(doc),
        onLongPress: () {
          final id = doc['id'] as String?;
          if (id != null) _deleteDocument(id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isNote
                    ? Icons.note_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppColors.accent(context),
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: AppColors.muted(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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

class _VaultFileViewer extends StatefulWidget {
  final String title;
  final Uint8List bytes;

  const _VaultFileViewer({required this.title, required this.bytes});

  @override
  State<_VaultFileViewer> createState() => _VaultFileViewerState();
}

class _VaultFileViewerState extends State<_VaultFileViewer> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  @override
  void initState() {
    super.initState();
    _secureChannel.invokeMethod('setSecure', true);
  }

  @override
  void dispose() {
    _secureChannel.invokeMethod('setSecure', false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 64, color: AppColors.muted(context)),
                const SizedBox(height: 12),
                Text('Unable to display this file',
                    style: TextStyle(color: AppColors.muted(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
