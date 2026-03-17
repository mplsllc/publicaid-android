import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/vault_service.dart';
import '../theme.dart';

class VaultEmergencyMedicalScreen extends StatefulWidget {
  final VaultService vaultService;

  const VaultEmergencyMedicalScreen({
    super.key,
    required this.vaultService,
  });

  @override
  State<VaultEmergencyMedicalScreen> createState() =>
      _VaultEmergencyMedicalScreenState();
}

class _VaultEmergencyMedicalScreenState
    extends State<VaultEmergencyMedicalScreen> {
  static const _secureChannel = MethodChannel('org.publicaid.app/secure');

  late final TextEditingController _conditionsController;
  late final TextEditingController _medicationsController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _doctorNameController;
  late final TextEditingController _doctorPhoneController;
  late final TextEditingController _pharmacyController;
  late final TextEditingController _insuranceIdController;

  String _bloodType = 'Unknown';
  bool _saving = false;

  static const _bloodTypes = [
    'Unknown',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _setSecure(true);

    final medical = widget.vaultService.getEmergencyMedical();

    _conditionsController = TextEditingController(
        text: medical?['conditions'] as String? ?? '');
    _medicationsController = TextEditingController(
        text: medical?['medications'] as String? ?? '');
    _allergiesController = TextEditingController(
        text: medical?['allergies'] as String? ?? '');
    _doctorNameController = TextEditingController(
        text: medical?['doctorName'] as String? ?? '');
    _doctorPhoneController = TextEditingController(
        text: medical?['doctorPhone'] as String? ?? '');
    _pharmacyController = TextEditingController(
        text: medical?['pharmacy'] as String? ?? '');
    _insuranceIdController = TextEditingController(
        text: medical?['insuranceId'] as String? ?? '');
    _bloodType = medical?['bloodType'] as String? ?? 'Unknown';
  }

  @override
  void dispose() {
    _setSecure(false);
    _conditionsController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _pharmacyController.dispose();
    _insuranceIdController.dispose();
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecure', secure);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'conditions': _conditionsController.text.trim(),
      'medications': _medicationsController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'bloodType': _bloodType,
      'doctorName': _doctorNameController.text.trim(),
      'doctorPhone': _doctorPhoneController.text.trim(),
      'pharmacy': _pharmacyController.text.trim(),
      'insuranceId': _insuranceIdController.text.trim(),
    };

    try {
      await widget.vaultService.saveEmergencyMedical(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Medical info saved'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save medical info')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  Future<void> _callDoctor() async {
    final phone = _doctorPhoneController.text.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Information'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Health'),
            const SizedBox(height: 12),
            _buildMultilineField(
              controller: _conditionsController,
              label: 'Conditions',
              hint: 'e.g. Diabetes, Asthma, Heart disease...',
            ),
            const SizedBox(height: 16),
            _buildMultilineField(
              controller: _medicationsController,
              label: 'Medications',
              hint: 'e.g. Insulin 10u daily, Albuterol PRN...',
            ),
            const SizedBox(height: 16),
            _buildMultilineField(
              controller: _allergiesController,
              label: 'Allergies',
              hint: 'e.g. Penicillin, Peanuts, Latex...',
            ),
            const SizedBox(height: 16),
            _buildDropdownField(),
            const SizedBox(height: 32),
            _buildSectionHeader('Healthcare'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _doctorNameController,
              label: 'Doctor Name',
            ),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pharmacyController,
              label: 'Pharmacy',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _insuranceIdController,
              label: 'Insurance ID',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'InstrumentSerif',
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: AppColors.text(context),
      ),
    );
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      maxLines: 3,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        color: AppColors.text(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        color: AppColors.text(context),
      ),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _doctorPhoneController,
      keyboardType: TextInputType.phone,
      style: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        color: AppColors.text(context),
      ),
      decoration: InputDecoration(
        labelText: 'Doctor Phone',
        suffixIcon: _doctorPhoneController.text.trim().isNotEmpty
            ? IconButton(
                icon: Icon(Icons.call, color: AppColors.accent(context)),
                onPressed: _callDoctor,
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDropdownField() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Blood Type'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _bloodType,
          isDense: true,
          isExpanded: true,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: AppColors.text(context),
          ),
          items: _bloodTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _bloodType = v);
          },
        ),
      ),
    );
  }
}
