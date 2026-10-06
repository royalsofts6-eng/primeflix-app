import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/models.dart';

class Prefs {
  static const _kMemberKey = 'member_key';
  static const _kFamilyFilter = 'family_filter';

  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String? get memberKey => _p.getString(_kMemberKey);
  static Future<void> setMemberKey(String key) =>
      _p.setString(_kMemberKey, key);
  static Future<void> clearMemberKey() => _p.remove(_kMemberKey);

  static bool get isLoggedIn => (memberKey ?? '').isNotEmpty;

  // ---- My List ----
  static const _kMyList = 'my_list';

  static List<TitleItem>? _myListCache;

  /// Returns a copy (callers may mutate). Decoded once, then cached.
  static List<TitleItem> get myList {
    final c = _myListCache;
    if (c != null) return List<TitleItem>.of(c);
    final raw = _p.getString(_kMyList);
    var l = <TitleItem>[];
    if (raw != null) {
      try {
        l = (jsonDecode(raw) as List)
            .map((e) => TitleItem.fromStore(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    _myListCache = l;
    return List<TitleItem>.of(l);
  }

  static bool inMyList(String id) => myList.any((t) => t.id == id);

  static Future<void> _saveMyList(List<TitleItem> l) {
    _myListCache = List<TitleItem>.of(l);
    return _p.setString(_kMyList, jsonEncode(l.map((e) => e.toStore()).toList()));
  }

  /// Adds if missing, removes if present. Returns true if now in list.
  static Future<bool> toggleMyList(TitleItem t) async {
    final l = myList;
    final exists = l.any((e) => e.id == t.id);
    if (exists) {
      l.removeWhere((e) => e.id == t.id);
    } else {
      l.insert(0, t);
    }
    await _saveMyList(l);
    return !exists;
  }

  /// Family filter is ON by default.
  static bool get familyFilter => _p.getBool(_kFamilyFilter) ?? true;
  /// Bumped when the family filter changes so lists re-filter live.
  static final ValueNotifier<int> filterRev = ValueNotifier<int>(0);
  static Future<void> setFamilyFilter(bool v) async {
    await _p.setBool(_kFamilyFilter, v);
    filterRev.value++;
  }

  // ---- Player / subtitle settings ----
  static const _kSubSize = 'sub_size';
  static const _kSubColor = 'sub_color';
  static const _kSubBg = 'sub_bg';
  static const _kSpeed = 'default_speed';
  static const _kAutoNext = 'autoplay_next';

  /// Subtitle font size in logical px (default 18).
  static double get subtitleSize => _p.getDouble(_kSubSize) ?? 18;
  static Future<void> setSubtitleSize(double v) => _p.setDouble(_kSubSize, v);

  /// Subtitle text color as ARGB int (default white).
  static int get subtitleColor => _p.getInt(_kSubColor) ?? 0xFFFFFFFF;
  static Future<void> setSubtitleColor(int v) => _p.setInt(_kSubColor, v);

  /// Dark box behind subtitles (default ON).
  static bool get subtitleBg => _p.getBool(_kSubBg) ?? true;
  static Future<void> setSubtitleBg(bool v) => _p.setBool(_kSubBg, v);

  /// Default playback speed (default 1.0).
  static double get defaultSpeed => _p.getDouble(_kSpeed) ?? 1.0;
  static Future<void> setDefaultSpeed(double v) => _p.setDouble(_kSpeed, v);

  /// Auto-play next episode (default ON).
  static bool get autoplayNext => _p.getBool(_kAutoNext) ?? true;
  static Future<void> setAutoplayNext(bool v) => _p.setBool(_kAutoNext, v);

  // ---- Data clearing ----
  static Future<void> clearMyList() {
    _myListCache = [];
    return _p.remove(_kMyList);
  }

  static Future<void> clearAllProgress() async {
    _progressCache = {};
    await _p.remove(_kProgress);
    progressRev.value++;
  }

  // ---- Playback progress (resume / Continue Watching) ----
  static const _kProgress = 'progress';

  static String progressKey(String id, int season, int episode) =>
      '$id|$season|$episode';

  static Map<String, dynamic>? _progressCache;

  /// Decoded once and cached; every writer goes through [_writeProgress].
  /// Treat the returned map as read-only (writers copy it first).
  static Map<String, dynamic> _progressMap() {
    final c = _progressCache;
    if (c != null) return c;
    Map<String, dynamic> m = {};
    final raw = _p.getString(_kProgress);
    if (raw != null) {
      try {
        m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return _progressCache = m;
  }

  static Future<void> _writeProgress(Map<String, dynamic> m) async {
    _progressCache = m;
    await _p.setString(_kProgress, jsonEncode(m));
    progressRev.value++;
  }

  /// Saved position in ms (0 if none).
  static int progressMs(String key) {
    final m = _progressMap()[key];
    if (m is Map) return (m['pos'] as num?)?.toInt() ?? 0;
    return 0;
  }

  static Duration progress(String key) =>
      Duration(milliseconds: progressMs(key));

  /// Bumped whenever progress changes (Home listens to refresh the row).
  static final ValueNotifier<int> progressRev = ValueNotifier<int>(0);

  /// 0..1 fraction watched for a key (0 if none).
  static double progressFraction(String key) {
    final m = _progressMap()[key];
    if (m is! Map || m['next'] == true) return 0;
    final pos = (m['pos'] as num?)?.toInt() ?? 0;
    final dur = (m['dur'] as num?)?.toInt() ?? 0;
    if (dur <= 0) return 0;
    return (pos / dur).clamp(0.0, 1.0).toDouble();
  }

  /// Saves position; clears it when (almost) finished or barely started.
  /// Pass [item] so the entry shows up in Continue Watching.
  static Future<void> saveProgress(
    String key,
    int posMs,
    int durMs, {
    TitleItem? item,
    String? contentId,
    int season = 0,
    int episode = 0,
  }) async {
    final m = Map<String, dynamic>.from(_progressMap());
    if (durMs > 0 && posMs >= durMs * 0.95) {
      m.remove(key);
    } else if (posMs > 5000) {
      final old = m[key];
      final prev = old is Map ? Map<String, dynamic>.from(old) : <String, dynamic>{};
      m[key] = {
        ...prev,
        'pos': posMs,
        'dur': durMs,
        'ts': DateTime.now().millisecondsSinceEpoch,
        if (item != null) 'item': item.toStore(),
        if (contentId != null) 'cid': contentId,
        'se': season,
        'ep': episode,
      }..remove('next');
    } else {
      return;
    }
    await _writeProgress(m);
  }

  /// Series: after finishing an episode, queue the next one so the title
  /// stays in Continue Watching as "Up next" (no real progress yet).
  static Future<void> markUpNext(
    TitleItem item,
    String contentId,
    int season,
    int episode,
  ) async {
    final m = Map<String, dynamic>.from(_progressMap());
    final key = progressKey(contentId, season, episode);
    if (m[key] is Map && (m[key] as Map)['next'] != true) return; // real progress wins
    m[key] = {
      'pos': 1,
      'dur': 1,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'item': item.toStore(),
      'cid': contentId,
      'se': season,
      'ep': episode,
      'next': true,
    };
    await _writeProgress(m);
  }

  static Future<void> clearProgress(String key) async {
    final m = Map<String, dynamic>.from(_progressMap());
    if (m.remove(key) == null) return;
    await _writeProgress(m);
  }

  /// Removes every saved position of a title (all episodes / dubs).
  static Future<void> clearTitleProgress(String titleId) async {
    final m = Map<String, dynamic>.from(_progressMap());
    m.removeWhere((_, v) =>
        v is Map && v['item'] is Map && (v['item'] as Map)['id']?.toString() == titleId);
    await _writeProgress(m);
  }

  /// Latest unfinished entry per title, newest first.
  static List<WatchEntry> get continueWatching {
    final byTitle = <String, WatchEntry>{};
    for (final v in _progressMap().values) {
      if (v is! Map || v['item'] is! Map) continue;
      final pos = (v['pos'] as num?)?.toInt() ?? 0;
      final dur = (v['dur'] as num?)?.toInt() ?? 0;
      if (pos <= 0 || dur <= 0) continue;
      final item = TitleItem.fromStore(Map<String, dynamic>.from(v['item'] as Map));
      if (item.id.isEmpty) continue;
      final e = WatchEntry(
        item: item,
        contentId: (v['cid'] ?? item.id).toString(),
        season: (v['se'] as num?)?.toInt() ?? 0,
        episode: (v['ep'] as num?)?.toInt() ?? 0,
        posMs: pos,
        durMs: dur,
        ts: (v['ts'] as num?)?.toInt() ?? 0,
        upNext: v['next'] == true,
      );
      final cur = byTitle[item.id];
      if (cur == null || e.ts > cur.ts) byTitle[item.id] = e;
    }
    final l = byTitle.values.toList()..sort((a, b) => b.ts.compareTo(a.ts));
    return l.take(20).toList();
  }
}
