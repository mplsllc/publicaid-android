import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import 'vault_screen.dart';

class VaultSetupScreen extends StatefulWidget {
  final VaultService vaultService;
  const VaultSetupScreen({super.key, required this.vaultService});

  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _step = 0;

  // Step 2 — password
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;

  // Step 3 — backup codes
  late final List<String> _backupCodes;
  bool _codesConfirmed = false;
  bool _sharing = false;

  // Step 4 — PIN
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String? _pinError;
  bool _saving = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _backupCodes = widget.vaultService.generateBackupCodes();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _shakeController.reset();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _advance() async {
    // Request storage permission on the first step (welcome → password)
    if (_step == 0) {
      await _requestStoragePermission();
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _step++);
  }

  Future<void> _requestStoragePermission() async {
    // Request storage/media permissions so file uploads work.
    // permission_handler handles the Android version differences internally.
    final status = await Permission.storage.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
    // Also request photos for Android 13+ (no-op on older versions)
    await Permission.photos.request();
  }

  void _validatePassword() {
    final pw = _passwordController.text;
    if (pw.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }
    if (pw != _confirmController.text) {
      setState(() => _passwordError = 'Passwords do not match');
      return;
    }
    setState(() => _passwordError = null);
    _advance();
  }

  Future<void> _shareBackupCodes() async {
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/publicaid_vault_backup_codes.txt');
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final buffer = StringBuffer();
      buffer.writeln('Publicaid Vault — Backup Codes');
      buffer.writeln('Generated: $dateStr');
      buffer.writeln('');
      buffer.writeln(
          'Each code can be used once to recover your vault if you forget your PIN.');
      buffer.writeln('Keep this file somewhere safe and private.');
      buffer.writeln('');
      for (var i = 0; i < _backupCodes.length; i++) {
        buffer.writeln('  ${(i + 1).toString().padLeft(2)}. ${_backupCodes[i]}');
      }
      buffer.writeln('');
      buffer.writeln('publicaid.org');

      await file.writeAsString(buffer.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Publicaid Vault Backup Codes',
      );
    } catch (_) {
      // share sheet dismissed or error — not fatal
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _onDigit(int digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit.toString();
      _pinError = null;
    });
    if (_pin.length == 6) _onPinComplete();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = null;
    });
  }

  Future<void> _onPinComplete() async {
    HapticFeedback.lightImpact();

    if (!_isConfirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
      return;
    }

    if (_pin != _firstPin) {
      _shakeController.forward();
      HapticFeedback.heavyImpact();
      setState(() {
        _pinError = "PINs don't match";
        _pin = '';
        _firstPin = '';
        _isConfirming = false;
      });
      return;
    }

    // PINs match — create vault
    setState(() => _saving = true);
    try {
      await widget.vaultService.createVault(_passwordController.text, _pin);
      await widget.vaultService.saveBackupCodes(
          _backupCodes, _passwordController.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _pinError = 'Setup failed. Please try again.';
          _pin = '';
          _firstPin = '';
          _isConfirming = false;
        });
      }
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VaultScreen(vaultService: widget.vaultService),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -0.87),
            end: Alignment(0.5, 0.87),
            colors: [Color(0xFF0D3B6E), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcome(),
                    _buildPassword(),
                    _buildBackupCodes(),
                    _buildPin(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Welcome
  // ---------------------------------------------------------------------------

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 32),
          const Text(
            'Protect your documents',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 30,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your documents are encrypted and backed up securely. '
            "Let's set up your vault.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _PrimaryButton(label: 'Set Up Vault', onPressed: _advance),
          const SizedBox(height: 16),
          _SkipButton(
            label: 'Maybe later',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Password
  // ---------------------------------------------------------------------------

  Widget _buildPassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Choose a vault password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This password encrypts your documents. '
            'You will need it to recover your vault on a new device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildPasswordField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hint: 'Choose a strong password',
            obscured: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmController,
            focusNode: _confirmFocus,
            hint: 'Confirm password',
            obscured: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            onSubmitted: (_) => _validatePassword(),
          ),
          if (_passwordError != null) ...[
            const SizedBox(height: 12),
            Text(
              _passwordError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: Colors.red.shade300,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _PrimaryButton(label: 'Continue', onPressed: _validatePassword),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Remember this password — it\'s the only way to '
                    'recover your documents on a new device.',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscured,
    required VoidCallback onToggle,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscured,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white.withValues(alpha: 0.5),
            size: 22,
          ),
          onPressed: onToggle,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Backup codes
  // ---------------------------------------------------------------------------

  Widget _buildBackupCodes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Save your backup codes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'If you forget your PIN, use one of these codes to recover '
            'your vault. Each code can only be used once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 2×4 code grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                for (var row = 0; row < 4; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(child: _buildCodeCell(row * 2, _backupCodes[row * 2])),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCodeCell(row * 2 + 1, _backupCodes[row * 2 + 1])),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Share button
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _sharing ? null : _shareBackupCodes,
              icon: _sharing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    )
                  : const Icon(Icons.share_outlined, size: 18),
              label: Text(_sharing ? 'Sharing…' : 'Share / Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                textStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Confirmation checkbox
          GestureDetector(
            onTap: () => setState(() => _codesConfirmed = !_codesConfirmed),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _codesConfirmed
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _codesConfirmed
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: _codesConfirmed
                      ? const Icon(Icons.check,
                          size: 15, color: AppColors.navyBlue)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "I've saved my backup codes",
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Continue',
            onPressed: _codesConfirmed ? _advance : null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCodeCell(int index, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            '${index + 1}.',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4 — PIN
  // ---------------------------------------------------------------------------

  Widget _buildPin() {
    final title = _isConfirming ? 'Confirm your PIN' : 'Set a 6-digit PIN';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                if (_saving)
                  Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Setting up your vault…',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final dx = _shakeAnimation.value *
                          10 *
                          ((_shakeController.value * 6).round().isEven
                              ? 1
                              : -1);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        final filled = i < _pin.length;
                        return Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 20,
                    child: _pinError != null
                        ? Text(
                            _pinError!,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              color: Colors.red.shade300,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _buildNumpad(),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _buildNumpadRow([1, 2, 3]),
          const SizedBox(height: 16),
          _buildNumpadRow([4, 5, 6]),
          const SizedBox(height: 16),
          _buildNumpadRow([7, 8, 9]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64, height: 64),
              _buildNumpadButton(0),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: _onBackspace,
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumpadButton(d)).toList(),
    );
  }

  Widget _buildNumpadButton(int digit) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onDigit(digit),
          splashColor: Colors.white24,
          child: Center(
            child: Text(
              '$digit',
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button widgets
// ---------------------------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navyBlue,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SkipButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
