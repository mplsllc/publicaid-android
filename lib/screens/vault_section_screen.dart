import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/vault_service.dart';
import '../theme.dart';

class VaultSectionScreen extends StatefulWidget {
  final VaultService vaultService;
  final String section; // 'identity', 'insurance', 'general'
  final String sectionTitle; // 'Identity Documents', etc.
  final bool autoPickFile; // if true, trigger file picker on mount

  const VaultSectionScreen({
    super.key,
    required this.vaultService,
    required this.section,
    required this.sectionTitle,
    this.autoPickFile = false,
  });

  @override
  State<VaultSectionScreen> createState() => _VaultSectionScreenState();
}

class _VaultSectionScreenState extends State<VaultSectionScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};

  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setSecure(true);
    _loadDocuments();

    if (widget.autoPickFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickAndUploadFile();
      });
    }
  }

  @override
  void dispose() {
    _setSecure(false);
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecure', secure);
    } catch (_) {
      // Platform channel may not be available in all environments
    }
  }

  void _loadDocuments() {
    setState(() => _loading = true);
    try {
      final docs = widget.vaultService.getDocumentsBySection(widget.section);
      if (mounted) {
        setState(() {
          _documents = docs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // File viewing
  // ---------------------------------------------------------------------------

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
  // Delete handler
  // ---------------------------------------------------------------------------

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

      // Ask for a description
      if (!mounted) return;
      final description = await _showDescriptionDialog();
      if (description == null) return; // user cancelled

      setState(() => _loading = true);
      await widget.vaultService.addFileToSection(
        file.name,
        bytes,
        section: widget.section,
        description: description,
      );
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

  Future<String?> _showDescriptionDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Description'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Driver\'s license, front side',
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
        title: Text(widget.sectionTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add document',
            onPressed: _pickAndUploadFile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : _buildDocumentList(),
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
            'Tap + to add a document',
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
    final title = doc['title'] as String? ?? 'Untitled';
    final description = doc['description'] as String?;
    final createdAt = doc['createdAt'] as String?;
    final size = doc['sizeBytes'] as int? ?? doc['size'] as int? ?? 0;
    final icon = _iconForFile(title);

    final subtitle =
        '${_extensionLabel(title)} \u00B7 ${_formatBytes(size)}';

    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewFile(doc),
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
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 14,
                          color: AppColors.text(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: AppColors.muted(context),
                  size: 20,
                ),
                tooltip: 'Share',
                onPressed: () => _shareFile(doc),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image viewer
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
