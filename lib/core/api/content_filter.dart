import 'models.dart';
import '../storage/prefs.dart';

/// Family filter: hides adult / spam / junk titles. Applied to every list.
class ContentFilter {
  // Explicit-content markers. Stems (porn*, erotic*, nud*) catch variants.
  static final _blocked = RegExp(
    r'(?<![a-z0-9])(18\s?\+|xxx|porn\w*|erotic\w*|nude\w*|hentai|uncensored|'
    r'adults?[\s-]+(only|film|movie|video|content|entertainment)|'
    r'sex(y)?[\s-]+(tape|scene|video|film|story|stories|diary|diaries|slave|club)|'
    r'jav|softcore|camgirl|onlyfans)(?![a-z0-9])',
    caseSensitive: false,
  );

  // Legit mainstream titles that would otherwise trip the markers.
  static final _allow = RegExp(
    r'^(xxx:\s*return of xander cage|sex education|sex and the city|'
    r'sex and the city 2|and just like that)$',
    caseSensitive: false,
  );

  static bool isAllowed(TitleItem t) {
    if (t.id.isEmpty || t.title.trim().isEmpty) return false; // junk
    if (_allow.hasMatch(t.title.trim())) return true;
    if (_blocked.hasMatch(t.title)) return false;
    if (_blocked.hasMatch(t.genre)) return false;
    if (RegExp(r'(^|,\s*)(adult|erotica|porn)(\s*,|$)', caseSensitive: false)
        .hasMatch(t.genre)) {
      return false;
    }
    return true;
  }

  static List<TitleItem> apply(List<TitleItem> items) {
    if (!Prefs.familyFilter) {
      return items.where((t) => t.id.isNotEmpty && t.title.trim().isNotEmpty).toList();
    }
    return items.where(isAllowed).toList();
  }
}
