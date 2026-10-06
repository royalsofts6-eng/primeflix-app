import 'package:flutter/material.dart';
import '../../core/api/models.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import 'player_screen.dart';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}

/// Resume dialog. Returns true = resume, false = start over, null = dismissed.
Future<bool?> showResumeDialog(BuildContext context, Duration pos) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF16161D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Continue from ${fmtDuration(pos)}?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Start over',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Resume',
              style: TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Opens the player. If a saved position exists and [askResume] is true,
/// asks "Continue from mm:ss?" first.
Future<void> launchPlayer(
  BuildContext context, {
  required TitleItem item,
  required String contentId,
  int season = 0,
  int episode = 0,
  List<int> episodeNumbers = const [],
  List<int> seasons = const [],
  bool askResume = true,
}) async {
  final s = item.isSeries ? season : 0;
  final e = item.isSeries ? episode : 0;
  final key = Prefs.progressKey(contentId, s, e);
  final posMs = Prefs.progressMs(key);

  var startOver = false;
  if (askResume && posMs > 5000) {
    final r = await showResumeDialog(context, Duration(milliseconds: posMs));
    if (r == null || !context.mounted) return;
    startOver = !r;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerScreen(
        contentId: contentId,
        title: item.title,
        isSeries: item.isSeries,
        season: s,
        episode: e,
        episodeNumbers: episodeNumbers,
        seasons: seasons,
        item: item,
        startOver: startOver,
      ),
    ),
  );
}
