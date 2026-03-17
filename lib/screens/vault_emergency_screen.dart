import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';
import 'vault_emergency_contacts_screen.dart';
import 'vault_emergency_medical_screen.dart';
import 'vault_emergency_bookmarks_screen.dart';
import 'vault_note_screen.dart';

class VaultEmergencyScreen extends StatefulWidget {
  final VaultService vaultService;
  final BookmarkService? bookmarkService;

  const VaultEmergencyScreen({
    super.key,
    required this.vaultService,
    this.bookmarkService,
  });

  @override
  State<VaultEmergencyScreen> createState() => _VaultEmergencyScreenState();
}

class _VaultEmergencyScreenState extends State<VaultEmergencyScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  @override
  void initState() {
    super.initState();
    _setSecure(true);
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

  // ---------------------------------------------------------------------------
  // Data summaries
  // ---------------------------------------------------------------------------

  String _contactsSummary() {
    try {
      final contacts = widget.vaultService.getEmergencyContacts();
      if (contacts.isEmpty) return 'Not set up';
      return '${contacts.length} contact${contacts.length == 1 ? '' : 's'}';
    } catch (_) {
      return 'Not set up';
    }
  }

  String _medicalSummary() {
    try {
      final medical = widget.vaultService.getEmergencyMedical();
      if (medical == null) return 'Not set up';
      final parts = <String>[];
      if ((medical['conditions'] as String?)?.isNotEmpty == true) {
        parts.add('Conditions');
      }
      if ((medical['medications'] as String?)?.isNotEmpty == true) {
        parts.add('Medications');
      }
      if ((medical['allergies'] as String?)?.isNotEmpty == true) {
        parts.add('Allergies');
      }
      if (parts.isEmpty) return 'Not set up';
      return parts.join(', ');
    } catch (_) {
      return 'Not set up';
    }
  }

  String _notesSummary() {
    try {
      final notes = widget.vaultService.getEmergencyNotes();
      if (notes.isEmpty) return 'No notes';
      return '${notes.length} note${notes.length == 1 ? '' : 's'}';
    } catch (_) {
      return 'No notes';
    }
  }

  String _bookmarksSummary() {
    try {
      final bookmarks = widget.vaultService.getEmergencyBookmarks();
      if (bookmarks.isEmpty) return 'Not synced';
      return '${bookmarks.length} service${bookmarks.length == 1 ? '' : 's'}';
    } catch (_) {
      return 'Not synced';
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultEmergencyContactsScreen(
          vaultService: widget.vaultService,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openMedical() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultEmergencyMedicalScreen(
          vaultService: widget.vaultService,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EmergencyNotesListScreen(
          vaultService: widget.vaultService,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultEmergencyBookmarksScreen(
          vaultService: widget.vaultService,
          bookmarkService: widget.bookmarkService!,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            icon: Icons.contacts_outlined,
            title: 'Emergency Contacts',
            subtitle: _contactsSummary(),
            onTap: _openContacts,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.medical_information_outlined,
            title: 'Medical Information',
            subtitle: _medicalSummary(),
            onTap: _openMedical,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.note_outlined,
            title: 'Secure Notes',
            subtitle: _notesSummary(),
            onTap: _openNotes,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.bookmark_outlined,
            title: 'My Saved Services',
            subtitle: _bookmarksSummary(),
            onTap: widget.bookmarkService != null ? _openBookmarks : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: AppColors.muted(context),
                      ),
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
}

// ---------------------------------------------------------------------------
// Emergency Notes List (internal screen)
// ---------------------------------------------------------------------------

class _EmergencyNotesListScreen extends StatefulWidget {
  final VaultService vaultService;

  const _EmergencyNotesListScreen({required this.vaultService});

  @override
  State<_EmergencyNotesListScreen> createState() =>
      _EmergencyNotesListScreenState();
}

class _EmergencyNotesListScreenState extends State<_EmergencyNotesListScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _setSecure(true);
    _loadNotes();
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

  void _loadNotes() {
    setState(() {
      _notes = widget.vaultService.getEmergencyNotes();
    });
  }

  void _addNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultNoteScreen(
          vaultService: widget.vaultService,
          section: 'emergency',
        ),
      ),
    ).then((_) => _loadNotes());
  }

  void _editNote(Map<String, dynamic> note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultNoteScreen(
          vaultService: widget.vaultService,
          existingNote: note,
        ),
      ),
    ).then((_) => _loadNotes());
  }

  Future<void> _deleteNote(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This note will be permanently deleted.'),
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
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Notes'),
      ),
      body: _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 64,
                    color: AppColors.muted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No emergency notes',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a note',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = _notes[index];
                final title = note['title'] as String? ?? 'Untitled';
                final content = note['content'] as String? ?? '';
                final preview = content.split('\n').first;

                return Card(
                  color: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.cardBorderOf(context)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _editNote(note),
                    onLongPress: () {
                      final id = note['id'] as String?;
                      if (id != null) _deleteNote(id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
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
                                if (preview.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontSize: 13,
                                      color: AppColors.muted(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        backgroundColor: AppColors.accent(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
