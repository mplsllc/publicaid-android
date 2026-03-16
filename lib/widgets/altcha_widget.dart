import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/auth.dart';
import '../services/api_service.dart';
import '../theme.dart';

// Top-level function so it can run in a background isolate via compute()
int? _solveChallengeSync(Map<String, dynamic> params) {
  final salt = params['salt'] as String;
  final challenge = params['challenge'] as String;
  final maxnumber = params['maxnumber'] as int;
  for (int n = 0; n <= maxnumber; n++) {
    final input = '$salt$n';
    final hash = sha256.convert(utf8.encode(input)).toString();
    if (hash == challenge) return n;
  }
  return null;
}

enum AltchaState { idle, loading, verified, error }

class AltchaWidget extends StatefulWidget {
  final ApiService apiService;
  final ValueChanged<String?> onVerified;

  const AltchaWidget({
    super.key,
    required this.apiService,
    required this.onVerified,
  });

  @override
  State<AltchaWidget> createState() => _AltchaWidgetState();
}

class _AltchaWidgetState extends State<AltchaWidget> {
  AltchaState _state = AltchaState.idle;
  String? _error;

  Future<void> _solve() async {
    setState(() {
      _state = AltchaState.loading;
      _error = null;
    });

    try {
      final challenge = await widget.apiService.getAltchaChallenge();
      final solution = await _solveChallenge(challenge);

      if (solution != null) {
        final payload = {
          'algorithm': challenge.algorithm,
          'challenge': challenge.challenge,
          'number': solution,
          'salt': challenge.salt,
          'signature': challenge.signature,
        };
        final encoded = base64Encode(utf8.encode(json.encode(payload)));
        setState(() => _state = AltchaState.verified);
        widget.onVerified(encoded);
      } else {
        setState(() {
          _state = AltchaState.error;
          _error = 'Verification failed. Please try again.';
        });
        widget.onVerified(null);
      }
    } catch (e) {
      setState(() {
        _state = AltchaState.error;
        _error = 'Could not verify. Please try again.';
      });
      widget.onVerified(null);
    }
  }

  Future<int?> _solveChallenge(AltchaChallenge challenge) {
    // Run in background isolate to avoid freezing the UI on Android
    return compute(_solveChallengeSync, {
      'salt': challenge.salt,
      'challenge': challenge.challenge,
      'maxnumber': challenge.maxnumber,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          _buildCheckbox(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _state == AltchaState.verified
                      ? 'Verified'
                      : _state == AltchaState.loading
                          ? 'Verifying...'
                          : 'I am human',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _state == AltchaState.verified
                        ? AppColors.greenAccent
                        : AppColors.navyBlue,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    switch (_state) {
      case AltchaState.idle:
      case AltchaState.error:
        return GestureDetector(
          onTap: _solve,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(
                color: _state == AltchaState.error
                    ? Colors.red
                    : AppColors.inputBorder,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      case AltchaState.loading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case AltchaState.verified:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.greenAccent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        );
    }
  }
}
