import 'package:intl/intl.dart' show NumberFormat;

import 'quantities.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'messages.dart';

const languageNames = {
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'it': 'Italiano',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'pt': 'Português',
  'ro': 'Română',
  'el': 'Ελληνικά',
  'hu': 'Magyar',
  'cs': 'Čeština',
};

class AppStrings {
  AppStrings(this.language)
    : _number = NumberFormat.decimalPattern(
        languageNames.containsKey(language) ? language : 'en',
      );
  final NumberFormat _number;
  static final _english = AppStrings('en');
  static final _placeholder = RegExp(r'\{(\d+)\}');
  final String language;
  String number(num value) => _number.format(value);
  static const delegate = _StringsDelegate();
  static final supportedLocales = [
    for (final code in languageNames.keys) localeFor(code),
  ];
  static Locale localeFor(String code) =>
      code == 'pt' ? const Locale('pt', 'PT') : Locale(code);
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? _english;
  String quantity(int count, String unit) {
    final forms = quantityUnits[language]?[unit] ?? quantityUnits['en']![unit]!;
    final index = switch (language) {
      'pl' =>
        count == 1
            ? 0
            : count % 10 >= 2 &&
                  count % 10 <= 4 &&
                  (count % 100 < 12 || count % 100 > 14)
            ? 1
            : 2,
      'cs' =>
        count == 1
            ? 0
            : count >= 2 && count <= 4
            ? 1
            : 2,
      'ro' =>
        count == 1
            ? 0
            : count == 0 || count % 100 >= 1 && count % 100 <= 19
            ? 1
            : 2,
      'fr' => count <= 1 ? 0 : 2,
      _ => count == 1 ? 0 : 2,
    };
    return '${_number.format(count)} ${forms[index]}';
  }

  String text(String source, [List<Object?> arguments = const []]) {
    final result = messages[language]?[source] ?? source;
    if (arguments.isEmpty) return result;
    return result.replaceAllMapped(_placeholder, (match) {
      final index = int.parse(match[1]!);
      if (index >= arguments.length) return match[0]!;
      final argument = arguments[index];
      return argument is num ? _number.format(argument) : '$argument';
    });
  }
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      languageNames.containsKey(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale.languageCode));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension InkoraTranslation on BuildContext {
  String tr(String source, [List<Object?> args = const []]) =>
      AppStrings.of(this).text(source, args);
}

/// Only application messages use this wrapper. Komga/user text remains Text.
class LText extends StatelessWidget {
  const LText(
    this.source, {
    super.key,
    this.arguments = const [],
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
    this.textWidthBasis,
    this.textDirection,
    this.strutStyle,
    this.textHeightBehavior,
  });
  final String source;
  final List<Object?> arguments;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  final TextWidthBasis? textWidthBasis;
  final TextDirection? textDirection;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  @override
  Widget build(BuildContext context) => Text(
    context.tr(source, arguments),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel == null ? null : context.tr(semanticsLabel!),
    textScaler: textScaler,
    textWidthBasis: textWidthBasis,
    textDirection: textDirection,
    strutStyle: strutStyle,
    textHeightBehavior: textHeightBehavior,
  );
}
