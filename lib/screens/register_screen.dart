import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/altcha_widget.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const RegisterScreen({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _altchaSolution;

  Future<void> _register() async {
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
      await widget.authService.register(
        _emailController.text.trim(),
        _passwordController.text,
        _confirmController.text,
        altcha: _altchaSolution,
      );

      if (mounted) {
        // Try auto-login with the same ALTCHA solution
        bool autoLoggedIn = false;
        try {
          await widget.authService.login(
            _emailController.text.trim(),
            _passwordController.text,
            altcha: _altchaSolution,
          );
          autoLoggedIn = true;
        } catch (_) {
          // Auto-login may fail if email verification is required
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(autoLoggedIn
                  ? 'Account created successfully!'
                  : 'Account created! Check your email to verify, then sign in.'),
              backgroundColor: AppColors.greenAccent,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        String msg;
        switch (e.message) {
          case 'email_already_registered':
            msg = 'An account with this email already exists';
            break;
          case 'passwords_do_not_match':
            msg = 'Passwords do not match';
            break;
          case 'verification_failed':
            msg = 'Verification failed. Please try again.';
            break;
          case 'validation_error':
            msg = 'Please check your input and try again.';
            break;
          default:
            msg = 'Registration failed. Please try again.';
        }
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Registration failed. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
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
                'Join Publicaid',
                style: TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 28,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create an account to save services across devices',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: 32),

              // Error banner
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

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email, AutofillHints.newUsername],
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

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
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
                  if (v.length < 8) return 'Password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm password
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 16),

              // ALTCHA verification
              AltchaWidget(
                apiService: widget.apiService,
                onVerified: (solution) {
                  setState(() => _altchaSolution = solution);
                },
              ),
              const SizedBox(height: 24),

              // Create account button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_loading || _altchaSolution == null) ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),

              // Login link
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
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
                          builder: (_) => LoginScreen(
                            authService: widget.authService,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Sign In',
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
