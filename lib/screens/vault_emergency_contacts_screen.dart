import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/vault_service.dart';
import '../theme.dart';

class VaultEmergencyContactsScreen extends StatefulWidget {
  final VaultService vaultService;

  const VaultEmergencyContactsScreen({
    super.key,
    required this.vaultService,
  });

  @override
  State<VaultEmergencyContactsScreen> createState() =>
      _VaultEmergencyContactsScreenState();
}

class _VaultEmergencyContactsScreenState
    extends State<VaultEmergencyContactsScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  List<Map<String, dynamic>> _contacts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _setSecure(true);
    _loadContacts();
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

  void _loadContacts() {
    setState(() {
      _contacts = widget.vaultService.getEmergencyContacts();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.vaultService.saveEmergencyContacts(_contacts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contacts saved'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save contacts')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  // ---------------------------------------------------------------------------
  // Import from device contacts
  // ---------------------------------------------------------------------------

  Future<void> _importFromContacts() async {
    final permStatus = await FlutterContacts.permissions.request(PermissionType.read);
    if (permStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact access needed to import. Please enable in device Settings.'),
        ),
      );
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts found on device')),
      );
      return;
    }

    // Show picker dialog
    final selected = await showDialog<List<Contact>>(
      context: context,
      builder: (ctx) => _ContactPickerDialog(contacts: contacts),
    );

    if (selected == null || selected.isEmpty) return;

    for (final contact in selected) {
      final name = contact.displayName ?? '';
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : '';
      final notes = '';

      _contacts.add({
        'name': name,
        'phone': phone,
        'relationship': '',
        'notes': notes,
      });
    }

    setState(() {});
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Add manually
  // ---------------------------------------------------------------------------

  Future<void> _addManually() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ContactFormDialog(),
    );

    if (result != null) {
      _contacts.add(result);
      setState(() {});
      await _save();
    }
  }

  // ---------------------------------------------------------------------------
  // Edit contact
  // ---------------------------------------------------------------------------

  Future<void> _editContact(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ContactFormDialog(existing: _contacts[index]),
    );

    if (result != null) {
      _contacts[index] = result;
      setState(() {});
      await _save();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete contact
  // ---------------------------------------------------------------------------

  Future<void> _deleteContact(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text(
            'Remove ${_contacts[index]['name'] ?? 'this contact'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _contacts.removeAt(index);
      setState(() {});
      await _save();
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importFromContacts,
                    icon: const Icon(Icons.import_contacts, size: 18),
                    label: const Text('Import from Contacts'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addManually,
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add Manually'),
                  ),
                ),
              ],
            ),
          ),

          // Contact list
          Expanded(
            child: _contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 64,
                          color: AppColors.muted(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No emergency contacts',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add contacts that should be reached\nin an emergency',
                          textAlign: TextAlign.center,
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
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildContactCard(index),
                  ),
          ),

          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildContactCard(int index) {
    final contact = _contacts[index];
    final name = contact['name'] as String? ?? 'Unknown';
    final phone = contact['phone'] as String? ?? '';
    final relationship = contact['relationship'] as String? ?? '';
    final notes = contact['notes'] as String? ?? '';

    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editContact(index),
        onLongPress: () => _deleteContact(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent(context).withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent(context),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (relationship.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tagBgOf(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              relationship,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _callPhone(phone),
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 14,
                            color: AppColors.accent(context),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: AppColors.muted(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact picker dialog
// ---------------------------------------------------------------------------

class _ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactPickerDialog({required this.contacts});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  final Set<int> _selected = {};
  String _search = '';

  List<Contact> get _filtered {
    if (_search.isEmpty) return widget.contacts;
    final q = _search.toLowerCase();
    return widget.contacts
        .where((c) => (c.displayName ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AlertDialog(
      title: const Text('Select Contacts'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final contact = filtered[i];
                  final globalIndex = widget.contacts.indexOf(contact);
                  final isSelected = _selected.contains(globalIndex);
                  final phone = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : '';

                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(
                      contact.displayName ?? '',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: AppColors.text(context),
                      ),
                    ),
                    subtitle: phone.isNotEmpty
                        ? Text(
                            phone,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: AppColors.muted(context),
                            ),
                          )
                        : null,
                    dense: true,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(globalIndex);
                        } else {
                          _selected.remove(globalIndex);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  final result = _selected
                      .map((i) => widget.contacts[i])
                      .toList();
                  Navigator.pop(context, result);
                },
          child: Text('Import (${_selected.length})'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact form dialog
// ---------------------------------------------------------------------------

class _ContactFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _ContactFormDialog({this.existing});

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.existing?['name'] as String? ?? '');
    _phoneController = TextEditingController(
        text: widget.existing?['phone'] as String? ?? '');
    _relationshipController = TextEditingController(
        text: widget.existing?['relationship'] as String? ?? '');
    _notesController = TextEditingController(
        text: widget.existing?['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    Navigator.pop(context, {
      'name': name,
      'phone': _phoneController.text.trim(),
      'relationship': _relationshipController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Contact' : 'Add Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationshipController,
              decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g. Spouse, Parent, Friend'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
