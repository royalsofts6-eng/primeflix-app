import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/api/content_filter.dart';
import '../../../core/api/models.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/loading.dart';

/// "Continue Watching" row with gold progress bars. Rebuilds whenever
/// playback progress changes. Tap = resume, long-press = remove.
class ContinueRow extends StatelessWidget {
  final ValueChanged<WatchEntry> onTap;
  const ContinueRow({super.key, required this.onTap});

  Future<void> _confirmRemove(BuildContext context, WatchEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from Continue Watching?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(e.item.title,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await Prefs.clearTitleProgress(e.item.id);
  }

  String _subtitle(WatchEntry e) {
    if (e.upNext) return 'S${e.season} E${e.episode} • Up next';
    final left = e.remaining.inMinutes;
    final lefTxt = left <= 0 ? 'Almost done' : '${left}m left';
    return e.season > 0 ? 'S${e.season} E${e.episode} • $lefTxt' : lefTxt;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Prefs.progressRev,
      builder: (context, _, __) {
        final items = Prefs.continueWatching
            .where((e) => ContentFilter.apply([e.item]).isNotEmpty)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();
        const w = 120.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('Continue Watching',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: w * 1.5 + 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return GestureDetector(
                    onTap: () => onTap(e),
                    onLongPress: () => _confirmRemove(context, e),
                    child: SizedBox(
                      width: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: w,
                              height: w * 1.5,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  e.item.poster.isEmpty
                                      ? Container(
                                          color: AppColors.glass,
                                          child: const Icon(Icons.movie_outlined,
                                              color: AppColors.textSecondary))
                                      : CachedNetworkImage(
                                          imageUrl: e.item.poster,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const ShimmerBox(
                                              width: w, height: w * 1.5),
                                          errorWidget: (_, __, ___) => Container(
                                              color: AppColors.glass),
                                        ),
                                  const Center(
                                    child: Icon(Icons.play_circle_fill_rounded,
                                        color: Colors.white70, size: 38),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: LinearProgressIndicator(
                                      value: e.fraction,
                                      minHeight: 4,
                                      color: AppColors.gold,
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(e.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(_subtitle(e),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
