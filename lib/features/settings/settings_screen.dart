import 'package:flutter/material.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass.dart';
import '../auth/login_screen.dart';

const appVersion = '1.0.0 (1)';

/// iOS-style grouped settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _colors = <String, int>{
    'White': 0xFFFFFFFF,
    'Yellow': 0xFFFFE066,
    'Gold': 0xFFD4AF37,
    'Cyan': 0xFF7FE7FF,
    'Green': 0xFF9BFF9B,
  };

  void _refresh() => setState(() {});

  // ------------------------------------------------------------- helpers

  Widget _section(String title, List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(height: 1, color: AppColors.glassBorder));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          GlassCard(
              padding: EdgeInsets.zero,
              radius: 16,
              child: Column(children: rows)),
        ],
      ),
    );
  }

  Widget _switch(String title, String sub, bool value, Future<void> Function(bool) set) {
    return SwitchListTile(
      activeColor: AppColors.gold,
      title: Text(title),
      subtitle: Text(sub, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: (v) async {
        await set(v);
        _refresh();
      },
    );
  }

  Future<bool> _confirm(String title, String msg, String action,
      {bool danger = true}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(msg, style: Theme.of(context).textTheme.bodySmall),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action,
                  style: TextStyle(
                      color: danger ? Colors.redAccent : AppColors.gold,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return r ?? false;
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF23232D),
        duration: const Duration(seconds: 2),
      ));
  }

  String _speedLabel(double s) => s == 1.0 ? 'Normal' : '${s}x';

  String _colorName(int c) => _colors.entries
      .firstWhere((e) => e.value == c,
          orElse: () => const MapEntry('Custom', 0))
      .key;

  // ------------------------------------------------------------- sheets

  Future<void> _pickSpeed() async {
    final v = await _sheet<double>(
      'Default playback speed',
      [for (final s in _speeds) (_speedLabel(s), s)],
      Prefs.defaultSpeed,
    );
    if (v != null) {
      await Prefs.setDefaultSpeed(v);
      _refresh();
    }
  }

  Future<void> _pickColor() async {
    final v = await _sheet<int>(
      'Subtitle color',
      [for (final e in _colors.entries) (e.key, e.value)],
      Prefs.subtitleColor,
    );
    if (v != null) {
      await Prefs.setSubtitleColor(v);
      _refresh();
    }
  }

  Future<T?> _sheet<T>(String title, List<(String, T)> opts, T selected) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            radius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                for (final o in opts)
                  ListTile(
                    title: Text(o.$1),
                    trailing: o.$2 == selected
                        ? const Icon(Icons.check_rounded, color: AppColors.gold)
                        : null,
                    onTap: () => Navigator.pop(context, o.$2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showText(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(12),
          child: GlassCard(
            radius: 20,
            padding: EdgeInsets.zero,
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(22),
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text(body, style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final key = Prefs.memberKey ?? '';
    final masked = key.length <= 4
        ? '••••'
        : '${'•' * (key.length - 4).clamp(2, 10)}${key.substring(key.length - 4)}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text('Settings',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _section('Content', [
            _switch('Family Filter', 'Hide adult and junk titles',
                Prefs.familyFilter, Prefs.setFamilyFilter),
          ]),
          _section('Playback', [
            ListTile(
              title: const Text('Default speed'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_speedLabel(Prefs.defaultSpeed),
                    style: Theme.of(context).textTheme.bodySmall),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ]),
              onTap: _pickSpeed,
            ),
            _switch('Autoplay next episode', 'Continue a series automatically',
                Prefs.autoplayNext, Prefs.setAutoplayNext),
          ]),
          _section('Subtitles', [
            // Live preview
            Container(
              height: 90,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B1B26), Color(0xFF0F0F16)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Prefs.subtitleBg
                      ? Colors.black.withOpacity(0.55)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('This is how subtitles look',
                    style: TextStyle(
                      fontSize: Prefs.subtitleSize,
                      fontWeight: FontWeight.w500,
                      color: Color(Prefs.subtitleColor),
                      shadows: Prefs.subtitleBg
                          ? null
                          : const [Shadow(blurRadius: 4, color: Colors.black)],
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const Text('Size'),
                Expanded(
                  child: Slider(
                    activeColor: AppColors.gold,
                    min: 14,
                    max: 30,
                    divisions: 8,
                    value: Prefs.subtitleSize.clamp(14, 30).toDouble(),
                    label: '${Prefs.subtitleSize.round()}',
                    onChanged: (v) {
                      Prefs.setSubtitleSize(v);
                      _refresh();
                    },
                  ),
                ),
                Text('${Prefs.subtitleSize.round()}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            ListTile(
              title: const Text('Color'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(Prefs.subtitleColor),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_colorName(Prefs.subtitleColor),
                    style: Theme.of(context).textTheme.bodySmall),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ]),
              onTap: _pickColor,
            ),
            _switch('Background box', 'Dark box behind subtitle text',
                Prefs.subtitleBg, Prefs.setSubtitleBg),
          ]),
          _section('Data', [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Clear watch history'),
              subtitle: Text('Removes Continue Watching & resume points',
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: () async {
                if (await _confirm('Clear watch history?',
                    'All resume positions will be removed.', 'Clear')) {
                  await Prefs.clearAllProgress();
                  _toast('Watch history cleared');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: const Text('Clear My List'),
              onTap: () async {
                if (await _confirm('Clear My List?',
                    'All saved titles will be removed.', 'Clear')) {
                  await Prefs.clearMyList();
                  _toast('My List cleared');
                }
              },
            ),
          ]),
          _section('About', [
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: const Text('Member key'),
              trailing: Text(masked,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About PrimeFlix'),
              trailing: Text(appVersion,
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: () => _showText('About PrimeFlix',
                  'PrimeFlix $appVersion\n\nA native Android player with hardware HEVC decoding via ExoPlayer, built for smooth playback of movies and series.'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _showText('Privacy',
                  'PrimeFlix stores your member key, My List, subtitle/playback settings and watch progress only on this device.\n\nNo analytics or advertising trackers are included. Titles, posters and streams are requested from the PrimeFlix service when you browse or play.\n\nLogging out removes your member key; use "Clear watch history" and "Clear My List" to erase the rest.'),
            ),
          ]),
          _section('Account', [
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                if (!await _confirm('Log out?',
                    'You will need your member key to sign in again.', 'Logout')) {
                  return;
                }
                await Prefs.clearMemberKey();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ]),
        ],
      ),
    );
  }
}
