import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  final bool startInRegister;
  const LoginScreen({super.key, this.startInRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool registerMode = false;
  bool busy = false;
  bool obscurePassword = true;
  String error = '';
  final phone = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final town = TextEditingController(text: 'Kansanga');
  final address = TextEditingController();

  @override
  void initState() {
    super.initState();
    registerMode = widget.startInRegister;
  }

  Future<void> submit() async {
    // Mirror the server-side Django password validators so the user sees the
    // problem before the round trip.
    if (registerMode) {
      final pw = password.text;
      if (phone.text.trim().isEmpty) {
        setState(() => error = 'Enter your phone number.');
        return;
      }
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
      if (registerMode) {
        await session.register(
          phone: phone.text.trim(),
          password: password.text,
          fullName: fullName.text.trim(),
          town: town.text.trim(),
          address: address.text.trim(),
        );
      } else {
        await session.login(phone.text.trim(), password.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/bg.png',
                    width: 190,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'E-waste collection, tracking & rewards',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign in')),
                          ButtonSegment(value: true, label: Text('Register')),
                        ],
                        selected: {registerMode},
                        onSelectionChanged: (s) =>
                            setState(() => registerMode = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (error.isNotEmpty) ErrorBanner(message: error),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                if (registerMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: town,
                    decoration: const InputDecoration(labelText: 'Town / area'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    decoration:
                        const InputDecoration(labelText: 'Address (for pickups)'),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : registerMode
                            ? 'Create account'
                            : 'Sign in',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'One account works everywhere in EcoTrace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
