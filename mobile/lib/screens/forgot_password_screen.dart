import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../core/widgets.dart';

/// Two-step password reset: request a code from an administrator, then
/// exchange it for a new password and sign straight in.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialPhone;
  const ForgotPasswordScreen({super.key, this.initialPhone = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool sent = false;
  bool busy = false;
  bool obscurePassword = true;
  String error = '';
  String note = '';
  late final phone = TextEditingController(text: widget.initialPhone);
  final code = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (phone.text.trim().isEmpty) {
      setState(() => error = 'Enter your phone number.');
      return;
    }
    if (sent) {
      if (code.text.trim().length != 6) {
        setState(() => error = 'Enter the 6-digit code from EcoTrace support.');
        return;
      }
      final pw = password.text;
      if (pw.length < 8) {
        setState(() => error = 'Password must be at least 8 characters.');
        return;
      }
      if (int.tryParse(pw) != null) {
        setState(() => error = 'Password cannot be only numbers.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final session = context.read<Session>();
      if (!sent) {
        note = await session.requestPasswordReset(phone.text.trim());
        setState(() => sent = true);
      } else {
        await session.confirmPasswordReset(
          phone: phone.text.trim(),
          code: code.text.trim(),
          newPassword: password.text,
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sent
                      ? 'Enter the 6-digit code from an EcoTrace '
                          'administrator, then pick a new password.'
                      : 'Enter your phone number. An administrator will '
                          'give you a reset code — EcoTrace has no SMS '
                          'service.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted),
                ),
                const SizedBox(height: 20),
                if (error.isNotEmpty) ErrorBanner(message: error),
                if (note.isNotEmpty && sent)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF0FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB9D6F2)),
                    ),
                    child: Text(note, style: const TextStyle(color: kInk)),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  enabled: !sent,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                if (sent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Reset code',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        tooltip: obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : sent
                            ? 'Set new password'
                            : 'Request reset code',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
