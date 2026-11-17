import 'package:flutter/widgets.dart';
import 'package:kyndrel/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

export 'package:kyndrel/l10n/gen/app_localizations.dart';

/// Localisation (task 5.2). Strings live in `lib/l10n/app_*.arb`;
/// `flutter gen-l10n` (run by `flutter pub get`) writes `lib/l10n/gen/`.
abstract final class L10n {
  /// Locales the UI is translated into.
  static const List<Locale> supportedLocales =
      AppLocalizations.supportedLocales;

  /// App strings plus `material_ui`'s own Material/Cupertino/Widgets
  /// delegates (the generated list points at the deprecated
  /// `package:flutter/material.dart` types, so it isn't used).
  static const delegates = <LocalizationsDelegate<Object?>>[
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  /// The `language` setting as a [Locale]; null follows the system.
  static Locale? localeFor(String language) =>
      language == 'system' ? null : Locale(language);

  static final AppLocalizations _english = lookupAppLocalizations(
    const Locale('en'),
  );

  /// English strings, for code outside the widget tree (e.g. the OSD).
  static AppLocalizations get english => _english;
}

extension L10nContext on BuildContext {
  /// The UI strings. Falls back to English where no [AppLocalizations]
  /// is in scope (bare widget tests).
  AppLocalizations get l10n => AppLocalizations.of(this) ?? L10n.english;
}
