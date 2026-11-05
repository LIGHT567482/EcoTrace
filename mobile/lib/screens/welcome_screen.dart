import 'package:flutter/material.dart';

import '../core/widgets.dart';
import 'login_screen.dart';

/// App landing: shown before sign-in. Mobile-first, single screen.
/// intentionally different from the website's marketing landing page.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _open(BuildContext context, {required bool register}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(startInRegister: register)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: kSurface,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/bg.png',
                      width: 260,
                      height: 132,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Your old gadgets\naren’t garbage.\nThey’re raw material.',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 32,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A trusted place to manage e-waste collection, certified recycling '
                    'and rewards.',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => _open(context, register: true),
                          child: const Text('Get started'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            foregroundColor: kBrandDark,
                            side: const BorderSide(color: kBrand),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _open(context, register: false),
                          child: const Text('I already have an account'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Create an account to start tracking your e-waste.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kMuted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
