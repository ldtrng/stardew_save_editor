import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../ui/theme.dart';

const supportEmail = 'ldtrong258@gmail.com';
const privacyPolicyUrl = 'https://ldtrng.github.io/stardew_save_editor/privacy-policy.html';
const termsUrl = 'https://ldtrng.github.io/stardew_save_editor/terms.html';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static List<(String, String)> get _sections => [
    ('What stays on your device',
        'Your tracker progress (farms, checklists, notes) and the save files you open are stored only on this device. '
            'Backups of edited saves are kept in the app\'s private storage and are deleted when you uninstall the app. '
            'The app has no account and does not upload your saves anywhere.'),
    ('Files you choose',
        'The app reads a save file only when you pick it, or when you grant access to the Stardew Valley Saves folder. '
            'Edited saves are written only where you choose to save them.'),
    ('Advertising',
        'The app shows ads through Google AdMob. AdMob may collect device identifiers (such as the advertising ID), '
            'approximate location derived from IP address and usage data to show and measure ads. Where required '
            '(for example in the EEA/UK) you are asked for consent first, and you can change your choice anytime under '
            'Settings › Ad privacy choices. See Google\'s policy: policies.google.com/technologies/ads'),
    ('Children', 'The app is not directed at children under 13.'),
    ('Contact', 'Questions about privacy: $supportEmail'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Privacy policy'))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        for (final (title, body) in _sections) ...[
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(body, style: TextStyle(color: p.text)),
          SizedBox(height: 16),
        ],
      ]),
    );
  }
}
