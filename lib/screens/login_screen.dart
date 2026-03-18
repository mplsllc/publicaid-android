import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/altcha_widget.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _altchaSolution;
  bool _canUseBiometrics = false;
  bool _needsTotp = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final can = await widget.authService.canUseBiometrics();
    if (mounted) setState(() => _canUseBiometrics = can);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_altchaSolution == null) {
      setState(() => _error = 'Please complete the verification');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        altcha: _altchaSolution,
        totpCode: _needsTotp ? _totpController.text.trim() : null,
      );
      if (result['totp_required'] == true) {
        if (mounted) {
          setState(() {
            _needsTotp = true;
            _loading = false;
          });
        }
        return;
      }
      if (mounted) {
        TextInput.finishAutofillContext();
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        String msg;
        switch (e.message) {
          case 'invalid_credentials':
            msg = 'Invalid email or password';
            break;
          case 'email_not_verified':
            msg = 'Please verify your email first. Check your inbox.';
            break;
          case 'account_suspended':
            msg = 'Your account has been suspended';
            break;
          case 'verification_failed':
            msg = 'Verification failed. Please try again.';
            break;
          default:
            msg = 'Login failed. Please try again.';
        }
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to connect. Check your internet connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _biometricLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.biometricLogin();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Biometric sign in failed';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AutofillGroup(
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 28,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to access your saved services',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.errorBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: AppColors.errorText(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 14,
                            color: AppColors.errorText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),

              // TOTP input (shown when 2FA is required)
              if (_needsTotp) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.heroBgOf(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Two-factor authentication',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter the 6-digit code from your authenticator app',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _totpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: '6-digit code',
                          counterText: '',
                          prefixIcon: Icon(Icons.security, size: 20),
                        ),
                        validator: (v) {
                          if (_needsTotp && (v == null || v.length != 6)) {
                            return 'Enter a 6-digit code';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _login(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ALTCHA verification
              AltchaWidget(
                apiService: widget.apiService,
                onVerified: (solution) {
                  setState(() => _altchaSolution = solution);
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_loading || _altchaSolution == null) ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ),

              if (_canUseBiometrics) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _biometricLogin,
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text('Sign in with device credentials'),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: AppColors.muted(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisterScreen(
                            authService: widget.authService,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
