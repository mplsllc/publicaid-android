import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import 'vault_screen.dart';

/// The three modes the screen can operate in.
enum _VaultMode {
  /// No local vault, no remote vault — full setup (password + PIN).
  setup,

  /// Local vault exists — daily PIN unlock.
  pinUnlock,

  /// No local vault but remote vault exists — password recovery, then set PIN.
  recovery,
}

class VaultPinScreen extends StatefulWidget {
  final VaultService vaultService;
  const VaultPinScreen({super.key, required this.vaultService});

  @override
  State<VaultPinScreen> createState() => _VaultPinScreenState();
}

class _VaultPinScreenState extends State<VaultPinScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Mode detection
  // ---------------------------------------------------------------------------
  _VaultMode? _mode;
  bool _loading = true;

  // ---------------------------------------------------------------------------
  // Password fields (setup & recovery)
  // ---------------------------------------------------------------------------
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;
  bool _passwordSubmitting = false;
  bool _passwordStepDone = false; // setup: password accepted, now set PIN

  // ---------------------------------------------------------------------------
  // PIN fields (all modes)
  // ---------------------------------------------------------------------------
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String? _pinError;
  int _attempts = 0;
  bool _lockedOut = false;
  Timer? _lockoutTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
    _detectMode();
  }

  Future<void> _detectMode() async {
    final hasLocal = await widget.vaultService.hasVault();
    if (hasLocal) {
      if (mounted) setState(() { _mode = _VaultMode.pinUnlock; _loading = false; });
      return;
    }

    final hasRemote = await widget.vaultService.hasRemoteVault();
    if (mounted) {
      setState(() {
        _mode = hasRemote ? _VaultMode.recovery : _VaultMode.setup;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Password handling (setup + recovery)
  // ---------------------------------------------------------------------------

  Future<void> _onPasswordSubmit() async {
    final password = _passwordController.text;

    if (_mode == _VaultMode.setup) {
      // Validate password
      if (password.length < 8) {
        setState(() => _passwordError = 'Password must be at least 8 characters');
        return;
      }
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        setState(() => _passwordError = 'Passwords do not match');
        return;
      }
      // Password accepted — move to PIN setup step
      setState(() {
        _passwordError = null;
        _passwordStepDone = true;
      });
    } else if (_mode == _VaultMode.recovery) {
      if (password.isEmpty) {
        setState(() => _passwordError = 'Enter your vault password');
        return;
      }

      setState(() { _passwordSubmitting = true; _passwordError = null; });

      final success = await widget.vaultService.unlockWithPassword(password);

      if (!mounted) return;

      if (success) {
        // Password accepted — move to PIN setup step
        setState(() {
          _passwordSubmitting = false;
          _passwordStepDone = true;
        });
      } else {
        setState(() {
          _passwordSubmitting = false;
          _passwordError = 'Incorrect password';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PIN handling
  // ---------------------------------------------------------------------------

  void _onDigit(int digit) {
    if (_lockedOut || _pin.length >= 6) return;
    setState(() {
      _pin += digit.toString();
      _pinError = null;
    });
    if (_pin.length == 6) {
      _onPinComplete();
    }
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

    if (_mode == _VaultMode.pinUnlock) {
      // Daily unlock
      final success = await widget.vaultService.unlockWithPin(_pin);
      if (success) {
        _navigateToVault();
      } else {
        _handleFailedAttempt('Incorrect PIN');
      }
      return;
    }

    // Setup or recovery — PIN entry/confirmation
    if (!_isConfirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
    } else {
      if (_pin == _firstPin) {
        if (_mode == _VaultMode.setup) {
          await widget.vaultService.createVault(
            _passwordController.text,
            _pin,
          );
        } else {
          // Recovery — password already unlocked, just set the PIN
          await widget.vaultService.setPin(_pin);
        }
        _navigateToVault();
      } else {
        _shakeController.forward();
        HapticFeedback.heavyImpact();
        setState(() {
          _pinError = "PINs don't match";
          _pin = '';
          _firstPin = '';
          _isConfirming = false;
        });
      }
    }
  }

  void _handleFailedAttempt(String message) {
    _attempts++;
    _shakeController.forward();
    HapticFeedback.heavyImpact();

    if (_attempts >= 10) {
      setState(() {
        _lockedOut = true;
        _pinError = 'Too many attempts. Try again later.';
        _pin = '';
      });
      _lockoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _lockedOut = false;
            _attempts = 0;
            _pinError = null;
          });
        }
      });
    } else {
      setState(() {
        _pinError = message;
        _pin = '';
      });
    }
  }

  void _navigateToVault() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VaultScreen(vaultService: widget.vaultService),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  String get _title {
    if (_mode == _VaultMode.setup && !_passwordStepDone) {
      return 'Create your vault';
    }
    if (_mode == _VaultMode.recovery && !_passwordStepDone) {
      return 'Recover your vault';
    }
    if (_mode == _VaultMode.pinUnlock) {
      return 'Enter PIN';
    }
    // PIN step (setup or recovery after password)
    return _isConfirming ? 'Confirm your PIN' : 'Set a 6-digit PIN';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.navyBlue;

    if (_loading || _mode == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Show password form if in setup (before PIN step) or recovery (before PIN step)
    if ((_mode == _VaultMode.setup || _mode == _VaultMode.recovery) &&
        !_passwordStepDone) {
      return _buildPasswordForm();
    }

    // Otherwise show PIN pad (daily unlock, or setup/recovery PIN step)
    return _buildPinPad();
  }

  // ---------------------------------------------------------------------------
  // Password form
  // ---------------------------------------------------------------------------

  Widget _buildPasswordForm() {
    final isSetup = _mode == _VaultMode.setup;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),

          // Title
          Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            isSetup
                ? 'Choose a strong password to encrypt your documents.'
                : 'Enter your vault password to recover your documents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 36),

          // Password field
          _buildPasswordField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            hint: isSetup ? 'Choose a strong password' : 'Vault password',
            obscured: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            onSubmitted: isSetup
                ? (_) => _confirmFocusNode.requestFocus()
                : (_) => _onPasswordSubmit(),
          ),

          // Confirm field (setup only)
          if (isSetup) ...[
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              focusNode: _confirmFocusNode,
              hint: 'Confirm password',
              obscured: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              onSubmitted: (_) => _onPasswordSubmit(),
            ),
          ],

          // Error message
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

          // Submit button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _passwordSubmitting ? null : _onPasswordSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navyBlue,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _passwordSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.navyBlue,
                      ),
                    )
                  : Text(isSetup ? 'Continue' : 'Unlock'),
            ),
          ),

          // Recovery note (setup only)
          if (isSetup) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remember this password \u2014 it\u2019s the only way to '
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
          ],

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
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
  // PIN pad
  // ---------------------------------------------------------------------------

  Widget _buildPinPad() {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Title
        Text(
          _title,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),

        // PIN dots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final dx = _shakeAnimation.value *
                10 *
                ((_shakeController.value * 6).round().isEven ? 1 : -1);
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
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),

        // Error message
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

        const Spacer(flex: 1),

        // Numpad
        _buildNumpad(),

        const Spacer(flex: 1),
      ],
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
              // Empty spacer
              const SizedBox(width: 64, height: 64),
              // Zero
              _buildNumpadButton(0),
              // Backspace
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
          side: BorderSide(
            color: Colors.white24,
            width: 1,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _lockedOut ? null : () => _onDigit(digit),
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
