import 'package:flutter/material.dart';

import '../core/widgets.dart';

/// A single call-to-action shown inside the home placeholder.
class PlaceholderAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const PlaceholderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Default content for an otherwise empty home tab: a welcome card, starter
/// stats and a short "how it works" guide so first-run users see something
/// useful instead of a blank list.
class HomePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<PlaceholderAction> actions;

  const HomePlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: kMuted, height: 1.5),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actions)
                        FilledButton.tonalIcon(
                          onPressed: action.onTap,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _StatTile(label: 'Requests', value: '0'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _StatTile(label: 'Items logged', value: '0'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _StatTile(label: 'Rewards', value: '0'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How it works',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _Step(number: '1', text: 'Log the e-waste sitting at home.'),
                _Step(
                  number: '2',
                  text: 'A certified collector picks it up, or you drop it '
                      'off at a collection point.',
                ),
                _Step(
                  number: '3',
                  text: 'Recyclers process it and you earn mobile-money '
                      'rewards.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kBrand,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
