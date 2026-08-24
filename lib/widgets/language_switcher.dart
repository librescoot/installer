import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show appLocale;

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => PopupMenuButton<String>(
        tooltip: l10n.language,
        position: PopupMenuPosition.under,
        initialValue: locale.languageCode,
        onSelected: (code) => appLocale.value = Locale(code),
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 'de', child: Text(l10n.languageGerman)),
          PopupMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              // The name, not the code: the menu it opens says Deutsch and
              // English, so the button should too.
              Text(
                switch (locale.languageCode) {
                  'de' => l10n.languageGerman,
                  _ => l10n.languageEnglish,
                },
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade300),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
