import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import 'vault_screen.dart';

class VaultPinScreen extends StatefulWidget {
  final VaultService vaultService;
  const VaultPinScreen({super.key, required this.vaultService});

  @override
  State<VaultPinScreen> createState() => _VaultPinScreenState();
}

class _VaultPinScreenState extends State<VaultPinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstPin = ''; // stored during set-mode confirmation
  bool _isConfirming = false;
  bool _isSetMode = false;
  String? _error;
  bool _loading = true;
  int _attempts = 0;
  bool _lockedOut = false;
  Timer? _lockoutTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    _checkVaultStatus();
  }

  Future<void> _checkVaultStatus() async {
    final hasVault = await widget.vaultService.hasVault();
    if (mounted) {
      setState(() {
        _isSetMode = !hasVault;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _onDigit(int digit) {
    if (_lockedOut || _pin.length >= 6) return;
    setState(() {
      _pin += digit.toString();
      _error = null;
    });
    if (_pin.length == 6) {
      _onPinComplete();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _onPinComplete() async {
    HapticFeedback.lightImpact();

    if (_isSetMode) {
      if (!_isConfirming) {
        // First entry in set mode
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        // Confirming in set mode
        if (_pin == _firstPin) {
          await widget.vaultService.createVault(_pin);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => VaultScreen(vaultService: widget.vaultService),
              ),
            );
          }
        } else {
          _shakeController.forward();
          HapticFeedback.heavyImpact();
          setState(() {
            _error = "PINs don't match";
            _pin = '';
            _firstPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Unlock mode
      final success = await widget.vaultService.unlockVault(_pin);
      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VaultScreen(vaultService: widget.vaultService),
            ),
          );
        }
      } else {
        _attempts++;
        _shakeController.forward();
        HapticFeedback.heavyImpact();

        if (_attempts >= 10) {
          setState(() {
            _lockedOut = true;
            _error = 'Too many attempts. Try again later.';
            _pin = '';
          });
          _lockoutTimer = Timer(const Duration(seconds: 30), () {
            if (mounted) {
              setState(() {
                _lockedOut = false;
                _attempts = 0;
                _error = null;
              });
            }
          });
        } else {
          setState(() {
            _error = 'Incorrect PIN';
            _pin = '';
          });
        }
      }
    }
  }

  String get _title {
    if (_isSetMode) {
      return _isConfirming ? 'Confirm your PIN' : 'Set a 6-digit PIN';
    }
    return 'Enter PIN';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.navyBlue;

    if (_loading) {
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
        child: Column(
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
              child: _error != null
                  ? Text(
                      _error!,
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
        ),
      ),
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
