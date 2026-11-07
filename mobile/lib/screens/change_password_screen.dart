import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../core/widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool busy = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  String error = '';
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (next.text != confirm.text) {
      setState(() => error = 'The new passwords do not match.');
      return;
    }
    if (next.text.length < 8) {
      setState(() => error = 'Password must be at least 8 characters.');
      return;
    }
    if (int.tryParse(next.text) != null) {
      setState(() => error = 'Password cannot be only numbers.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await context.read<Session>().changePassword(
            oldPassword: current.text,
            newPassword: next.text,
          );
      if (!mounted) return;
      current.clear();
      next.clear();
      confirm.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Use a password you do not use anywhere else.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 20),
                if (error.isNotEmpty) ErrorBanner(message: error),
                TextField(
                  controller: current,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      tooltip: obscureCurrent
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      tooltip:
                          obscureNew ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Please wait…' : 'Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
