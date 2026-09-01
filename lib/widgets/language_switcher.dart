import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show appLocale;

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final names = {'de': l10n.languageGerman, 'en': l10n.languageEnglish};

    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MenuAnchor(
        // A MenuAnchor, so this list arrives on the same surface as every
        // other menu in the app rather than on the M3 default.
        menuChildren: [
          for (final entry in names.entries)
            MenuItemButton(
              onPressed: () => appLocale.value = Locale(entry.key),
              leadingIcon: Icon(
                Icons.check,
                size: 16,
                color: entry.key == locale.languageCode
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
              child: Text(entry.value),
            ),
        ],
        builder: (context, controller, child) => Tooltip(
          message: l10n.language,
          child: InkWell(
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(6),
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
                    names[locale.languageCode] ?? names['en']!,
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.grey.shade300),
                  ),
                  Icon(Icons.arrow_drop_down,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
