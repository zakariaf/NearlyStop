/// Reading the ARB files as data.
///
/// Two suites assert things about the raw JSON rather than about the generated
/// class — the ICU shapes and the string budgets — and both were declaring
/// their own locale list and their own reader. A locale added to one and not
/// the other is a suite that silently stops covering it.
library;

import 'dart:convert';
import 'dart:io';

/// The four locales, as gen-l10n names their files.
///
/// Deliberately strings rather than `Locale`s: these suites are pure
/// `package:test` and must not pull in `dart:ui` to read a JSON file.
const List<String> arbLocaleTags = <String>['en', 'de', 'fa', 'ckb'];

/// The template locale every other one is compared against.
const String arbTemplateTag = 'en';

final Map<String, Map<String, dynamic>> _cache =
    <String, Map<String, dynamic>>{};

/// The parsed ARB for [tag], read once per process.
///
/// Cached because the callers index it inside loops over four locales and
/// sixty-seven keys, and re-parsing the file each time made the budget suite
/// do it several hundred times.
Map<String, dynamic> arbFor(String tag) => _cache.putIfAbsent(
  tag,
  () =>
      jsonDecode(File('lib/l10n/arb/app_$tag.arb').readAsStringSync())
          as Map<String, dynamic>,
);

/// The template's message keys, `@`-metadata excluded.
List<String> arbMessageKeys() =>
    arbFor(arbTemplateTag).keys.where((k) => !k.startsWith('@')).toList();
