import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    _cleanupTempFiles();
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

  // ---------------------------------------------------------------------------
  // Tap handler
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // File viewing
  // ---------------------------------------------------------------------------

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};

  bool _isImageFile(String title) {
    final lower = title.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  Future<void> _viewFile(Map<String, dynamic> doc) async {
    final id = doc['id'] as String;
    final title = doc['title'] as String? ?? 'File';

    setState(() => _loading = true);

    try {
      if (_isImageFile(title)) {
        // Images: decrypt in-memory and show with InteractiveViewer.
        final decryptedBytes = await widget.vaultService.downloadFile(id);
        setState(() => _loading = false);

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _VaultFileViewer(
              title: title,
              bytes: decryptedBytes,
            ),
          ),
        );
      } else {
        // Non-image files: decrypt to temp path and open with system viewer.
        final path = await widget.vaultService.decryptToTempFile(id);
        setState(() => _loading = false);

        if (!mounted) return;

        final result = await OpenFilex.open(path);

        if (!mounted) return;

        switch (result.type) {
          case ResultType.done:
            break;
          case ResultType.noAppToOpen:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No app available to open this file type')),
            );
            break;
          case ResultType.permissionDenied:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission denied')),
            );
            break;
          case ResultType.fileNotFound:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File not found')),
            );
            break;
          case ResultType.error:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open file')),
            );
            break;
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Share handler
  // ---------------------------------------------------------------------------

  Future<void> _shareFile(Map<String, dynamic> doc) async {
    try {
      final path =
          await widget.vaultService.decryptToTempFile(doc['id'] as String);
      await Share.shareXFiles(
        [XFile(path)],
        text: doc['title'] as String? ?? 'File',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share file')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Add menu
  // ---------------------------------------------------------------------------

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.upload_file_outlined,
                  color: AppColors.accent(context)),
              title: Text('Add Document',
                  style: TextStyle(color: AppColors.text(context))),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadFile();
              },
            ),
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
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add document via file picker
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      const maxSize = 10 * 1024 * 1024;
      if (file.size > maxSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large (max 10 MB)')),
          );
        }
        return;
      }

      Uint8List bytes;
      if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      setState(() => _loading = true);
      await widget.vaultService.addFile(file.name, bytes);
      _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} saved'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save file')),
        );
      }
    }
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

  IconData _iconForFile(String title) {
    final lower = title.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (_imageExtensions.any((ext) => lower.endsWith(ext))) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  String _extensionLabel(String title) {
    final dot = title.lastIndexOf('.');
    if (dot != -1 && dot < title.length - 1) {
      return title.substring(dot + 1).toUpperCase();
    }
    return 'FILE';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$m/$d/$y';
    } catch (_) {
      return '';
    }
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
            'Tap + to add a document or note',
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
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final createdAt = doc['createdAt'] as String?;

    // Subtitle
    String subtitle;
    if (isNote) {
      final content = doc['content'] as String? ?? '';
      subtitle = content.split('\n').first;
      if (subtitle.length > 80) {
        subtitle = '${subtitle.substring(0, 80)}...';
      }
      if (subtitle.isEmpty) subtitle = 'Empty note';
    } else {
      final size = doc['sizeBytes'] as int? ?? doc['size'] as int? ?? 0;
      subtitle = '${_extensionLabel(title)} \u00B7 ${_formatBytes(size)}';
    }

    // Icon
    final icon = isNote ? Icons.note_outlined : _iconForFile(title);

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
                icon,
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
                        fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isNote)
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: AppColors.muted(context),
                    size: 20,
                  ),
                  tooltip: 'Share',
                  onPressed: () => _shareFile(doc),
                )
              else
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

// ---------------------------------------------------------------------------
// Image viewer (kept as-is)
// ---------------------------------------------------------------------------

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
            errorBuilder: (_, _, _) => Column(
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
