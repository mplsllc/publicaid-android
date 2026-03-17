import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import '../theme.dart';

class VaultNoteScreen extends StatefulWidget {
  final VaultService vaultService;
  final Map<String, dynamic>? existingNote;
  final String? section;

  const VaultNoteScreen({
    super.key,
    required this.vaultService,
    this.existingNote,
    this.section,
  });

  @override
  State<VaultNoteScreen> createState() => _VaultNoteScreenState();
}

class _VaultNoteScreenState extends State<VaultNoteScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _saving = false;

  bool get _isEditMode => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _setSecure(true);
    _titleController = TextEditingController(
      text: widget.existingNote?['title'] as String? ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingNote?['content'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _setSecure(false);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecure', secure);
    } catch (_) {
      // Platform channel may not be available in all environments
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (_isEditMode) {
        final id = widget.existingNote!['id'] as String;
        await widget.vaultService.updateNote(id, title, content);
      } else {
        await widget.vaultService.addNote(title, content, section: widget.section);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save note')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Note' : 'New Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted(context),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
              textInputAction: TextInputAction.next,
              maxLines: 1,
            ),
            Divider(color: AppColors.cardBorderOf(context)),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  color: AppColors.text(context),
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'Start writing...',
                  hintStyle: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 15,
                    color: AppColors.muted(context),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
