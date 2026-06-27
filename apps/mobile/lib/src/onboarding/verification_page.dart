import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/session_service.dart';

class VerificationPage extends StatefulWidget {
  final String phoneNumber;

  const VerificationPage({super.key, required this.phoneNumber});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  int _resendCountdown = 30;
  Timer? _countdownTimer;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter verification code', style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Text('Sent to ${widget.phoneNumber}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
                decoration: InputDecoration(
                  labelText: '6-digit code',
                  counterText: '',
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
                onChanged: (v) {
                  setState(() => _errorMessage = '');
                  if (v.length == 6) _verify(v);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isVerifying
                    ? null
                    : () => _verify(_codeController.text.trim()),
                child: _isVerifying
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Didn\'t receive the code? ',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  _resendCountdown > 0
                      ? Text('Resend in ${_resendCountdown}s',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                      : TextButton(
                          onPressed: () {
                            _startResendCountdown();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code resent!')),
                            );
                          },
                          child: const Text('Resend'),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verify(String code) async {
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() { _isVerifying = true; _errorMessage = ''; });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // Stub: always accept "123456" or any 6-digit code
    if (code != '123456') {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid code. Try 123456 for demo.';
      });
      return;
    }

    if (!mounted) return;
    // Save a limited session (phone verified, no identity yet)
    final session = SessionService();
    await session.saveSession(
      token: widget.phoneNumber.hashCode.toString(),
      userId: '',
      username: '',
      phoneNumber: widget.phoneNumber,
    );
    if (!mounted) return;
    context.go('/home');
  }
}
