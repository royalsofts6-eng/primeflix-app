import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';

String fmtClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Glassmorphic overlay controls. Reads playback state from the underlying
/// video controller's ValueNotifier (typed dynamically so we don't depend on
/// better_player re-exporting its VideoPlayerValue type).
class PlayerControls extends StatefulWidget {
  final ValueNotifier<dynamic> vc;
  final String title;
  final String speedLabel;
  final bool hasQuality;
  final bool hasSubtitles;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final void Function(int seconds) onSeekBy;
  final void Function(Duration to) onSeekTo;
  final VoidCallback onSpeed;
  final VoidCallback onQuality;
  final VoidCallback onSubtitles;
  final VoidCallback? onNext;
  final VoidCallback onInteract; // keeps controls visible while scrubbing

  const PlayerControls({
    super.key,
    required this.vc,
    required this.title,
    required this.speedLabel,
    required this.hasQuality,
    required this.hasSubtitles,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeekBy,
    required this.onSeekTo,
    required this.onSpeed,
    required this.onQuality,
    required this.onSubtitles,
    required this.onInteract,
    this.onNext,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  double? _drag; // 0..1 while scrubbing

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: widget.vc,
      builder: (_, v, __) {
        final pos = v.position as Duration? ?? Duration.zero;
        final dur = (v.duration as Duration?) ?? Duration.zero;
        final playing = v.isPlaying as bool? ?? false;
        final buffering = v.isBuffering as bool? ?? false;
        final totalMs = dur.inMilliseconds;

        double bufferedFrac = 0;
        try {
          final b = v.buffered as List;
          if (b.isNotEmpty && totalMs > 0) {
            bufferedFrac =
                ((b.last.end as Duration).inMilliseconds / totalMs).clamp(0.0, 1.0);
          }
        } catch (_) {}

        final posFrac =
            totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
        final shownFrac = _drag ?? posFrac;
        final shownPos = _drag != null
            ? Duration(milliseconds: (totalMs * _drag!).round())
            : pos;

        return Stack(
          children: [
            // Gradient scrims for legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0, 0.28, 0.65, 1],
                  ),
                ),
              ),
            ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: widget.onBack,
                      ),
                      Expanded(
                        child: Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (widget.hasSubtitles)
                        IconButton(
                          icon: const Icon(Icons.subtitles_outlined),
                          onPressed: widget.onSubtitles,
                        ),
                      if (widget.hasQuality)
                        IconButton(
                          icon: const Icon(Icons.hd_outlined),
                          onPressed: widget.onQuality,
                        ),
                      TextButton(
                        onPressed: widget.onSpeed,
                        child: Text(widget.speedLabel,
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Center transport
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _glassIcon(Icons.replay_10_rounded, 30,
                      () => widget.onSeekBy(-10)),
                  const SizedBox(width: 28),
                  buffering
                      ? const SizedBox(
                          width: 76,
                          height: 76,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold),
                          ),
                        )
                      : _glassIcon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          44,
                          widget.onTogglePlay),
                  const SizedBox(width: 28),
                  _glassIcon(Icons.forward_10_rounded, 30,
                      () => widget.onSeekBy(10)),
                ],
              ),
            ),
            // Bottom: progress + time
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 28,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // buffered track
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: SizedBox(
                                  height: 3,
                                  child: Stack(
                                    children: [
                                      Container(color: Colors.white12),
                                      FractionallySizedBox(
                                        widthFactor: bufferedFrac,
                                        child: Container(color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: AppColors.gold,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: AppColors.gold,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                value: shownFrac.toDouble(),
                                onChangeStart: (_) => widget.onInteract(),
                                onChanged: totalMs == 0
                                    ? null
                                    : (f) {
                                        widget.onInteract();
                                        setState(() => _drag = f);
                                      },
                                onChangeEnd: (f) {
                                  setState(() => _drag = null);
                                  widget.onSeekTo(Duration(
                                      milliseconds: (totalMs * f).round()));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(fmtClock(shownPos),
                              style: const TextStyle(fontSize: 13)),
                          const Spacer(),
                          if (widget.onNext != null)
                            TextButton.icon(
                              onPressed: widget.onNext,
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: AppColors.gold, size: 20),
                              label: const Text('Next',
                                  style: TextStyle(color: AppColors.gold)),
                            ),
                          const Spacer(),
                          Text(fmtClock(dur),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glassIcon(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        widget.onInteract();
        onTap();
      },
      child: GlassCard(
        radius: 50,
        blur: 14,
        padding: EdgeInsets.all(size > 40 ? 16 : 12),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}
