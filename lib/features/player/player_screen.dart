import 'dart:async';
import 'dart:convert';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../core/api/models.dart';
import '../../core/api/moviebox_client.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/loading.dart';
import 'srt_parser.dart';
import 'widgets/option_sheet.dart';
import 'widgets/player_controls.dart';

/// Fullscreen player: ExoPlayer (via BetterPlayer) + DASH/HEVC, cookie headers,
/// custom glass controls, gestures, subtitles, quality/speed, autoplay-next
/// and resume-from-last-position.
class PlayerScreen extends StatefulWidget {
  final String contentId; // active id (changes with dub)
  final String title;
  final bool isSeries;
  final int season; // 0 for movies
  final int episode; // 0 for movies
  final List<int> episodeNumbers; // episodes in this season (for autoplay)
  final List<int> seasons; // all seasons (autoplay rolls into the next one)
  final TitleItem? item; // saved with progress -> Continue Watching
  final bool startOver; // ignore saved position on first load

  const PlayerScreen({
    super.key,
    required this.contentId,
    required this.title,
    required this.isSeries,
    this.season = 0,
    this.episode = 0,
    this.episodeNumbers = const [],
    this.seasons = const [],
    this.item,
    this.startOver = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _api = MovieBoxClient.shared;

  BetterPlayerController? _bp;
  ValueNotifier<dynamic>? _vc;

  List<StreamInfo> _streams = [];
  int _streamIdx = 0;
  late int _episode = widget.episode;
  late int _season = widget.season;
  late List<int> _episodeNumbers = widget.episodeNumbers;
  int _gen = 0; // bumps on every episode load (drops stale async results)
  late bool _startOver = widget.startOver;

  List<Subtitle> _captions = [];
  int _capIdx = -1; // -1 = off
  List<SubCue> _cues = [];

  double _speed = Prefs.defaultSpeed;
  bool _loading = true;
  String? _error;

  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _hudTimer;
  bool _finishedHandled = false;

  // gesture state
  Offset _dtPos = Offset.zero;
  bool _dragLeft = true;
  double _brightness = 0.5;
  double _volume = 0.5;
  String? _hudText;
  IconData? _hudIcon;

  String get _pkey => Prefs.progressKey(
      widget.contentId, widget.isSeries ? _season : 0, _episode);

  String get _displayTitle => widget.isSeries
      ? '${widget.title}  •  S$_season E$_episode'
      : widget.title;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initGestureValues();
    _loadEpisode();
  }

  Future<void> _initGestureValues() async {
    try {
      _brightness = await ScreenBrightness.instance.current;
    } catch (_) {}
    try {
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- loading

  static int _qualityNum(StreamInfo s) =>
      int.tryParse(RegExp(r'\d+').firstMatch(s.quality)?.group(0) ?? '') ?? 0;

  Future<void> _loadEpisode() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      _finishedHandled = false;
      _cues = [];
      _capIdx = -1;
      _captions = [];
    });
    await _disposeController();
    try {
      final s = await _api.sources(
        widget.contentId,
        season: widget.isSeries ? _season : 0,
        episode: widget.isSeries ? _episode : 0,
      );
      if (gen != _gen || !mounted) return;
      final valid = s.where((e) => e.url.isNotEmpty).toList();
      if (valid.isEmpty) {
        throw ApiException('No stream available for this title.');
      }
      valid.sort((a, b) => _qualityNum(b).compareTo(_qualityNum(a)));
      _streams = valid;
      _streamIdx = 0;
      _loadCaptions(gen);
      final startMs = _startOver ? 0 : Prefs.progressMs(_pkey);
      if (_startOver) await Prefs.clearProgress(_pkey);
      _startOver = false;
      await _initPlayer(startAt: Duration(milliseconds: startMs));
      if (!mounted) return;
      setState(() => _loading = false);
      _scheduleHide();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadCaptions(int gen) async {
    final id = _streams.isNotEmpty ? _streams.first.id : '';
    if (id.isEmpty) return;
    try {
      final c = await _api.captions(widget.contentId, id);
      // Ignore results that arrive after the episode changed.
      if (mounted && gen == _gen) setState(() => _captions = c.where((e) => e.url.isNotEmpty).toList());
    } catch (_) {
      // Captions are optional.
    }
  }

  Future<void> _initPlayer({Duration? startAt}) async {
    final st = _streams[_streamIdx];
    final ds = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      st.url,
      headers: st.headers, // Cookie: signCookie -> manifest + segments
      videoFormat: BetterPlayerVideoFormat.dash,
    );
    final c = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        fit: BoxFit.contain,
        startAt: startAt != null && startAt.inSeconds > 5 ? startAt : null,
        allowedScreenSleep: false,
        handleLifecycle: true,
        autoDispose: false,
        controlsConfiguration:
            const BetterPlayerControlsConfiguration(showControls: false),
      ),
      betterPlayerDataSource: ds,
    );
    c.addEventsListener(_onPlayerEvent);
    _bp = c;
    // videoPlayerController is created during setup; wait until it exists.
    for (var i = 0; i < 100 && c.videoPlayerController == null; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _vc = c.videoPlayerController;
    if (_vc == null) {
      throw ApiException('Player could not start. Try another quality.');
    }
    if (_speed != 1.0) {
      await c.setSpeed(_speed);
    }
    _saveTimer?.cancel();
    _saveTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
  }

  Future<void> _disposeController() async {
    _saveTimer?.cancel();
    final c = _bp;
    _bp = null;
    _vc = null;
    if (c != null) {
      c.removeEventsListener(_onPlayerEvent);
      c.dispose(forceDispose: true);
    }
  }

  void _onPlayerEvent(BetterPlayerEvent e) {
    if (!mounted) return;
    switch (e.betterPlayerEventType) {
      case BetterPlayerEventType.finished:
        _onFinished();
        break;
      case BetterPlayerEventType.exception:
        _onPlaybackError();
        break;
      default:
        break;
    }
  }

  bool _recovering = false;

  /// Playback failed (e.g. HEVC not decodable): silently try the next stream
  /// (lower quality) at the same position before showing an error.
  Future<void> _onPlaybackError() async {
    if (_recovering || _loading) return;
    final v = _vc?.value;
    final resume = (v?.position as Duration?) ?? Duration.zero;
    if (_streamIdx + 1 < _streams.length) {
      _recovering = true;
      final gen = _gen;
      setState(() => _loading = true);
      await _disposeController();
      _streamIdx++;
      try {
        await _initPlayer(startAt: resume);
        if (mounted && gen == _gen) {
          setState(() => _loading = false);
          _flash('Switched to ${_streamLabel(_streamIdx)}',
              Icons.swap_horiz_rounded);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
      _recovering = false;
      return;
    }
    if (mounted) {
      setState(() => _error =
          'This video could not be played on your device. Try another quality or retry later.');
    }
  }

  /// Retry keeps the chosen stream (unlike reloading from scratch).
  Future<void> _retry() async {
    if (_streams.isEmpty) return _loadEpisode();
    setState(() {
      _loading = true;
      _error = null;
    });
    await _disposeController();
    try {
      await _initPlayer(startAt: Prefs.progress(_pkey));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // --------------------------------------------------------------- progress

  void _saveProgress() {
    final v = _vc?.value;
    if (v == null) return;
    final pos = (v.position as Duration?) ?? Duration.zero;
    final dur = (v.duration as Duration?) ?? Duration.zero;
    Prefs.saveProgress(
      _pkey,
      pos.inMilliseconds,
      dur.inMilliseconds,
      item: widget.item,
      contentId: widget.contentId,
      season: widget.isSeries ? _season : 0,
      episode: widget.isSeries ? _episode : 0,
    );
  }

  int? get _nextEpisode {
    if (!widget.isSeries) return null;
    final eps = [..._episodeNumbers]..sort();
    final i = eps.indexOf(_episode);
    return (i >= 0 && i + 1 < eps.length) ? eps[i + 1] : null;
  }

  int? get _nextSeason {
    if (!widget.isSeries) return null;
    final ss = [...widget.seasons]..sort();
    final i = ss.indexOf(_season);
    return (i >= 0 && i + 1 < ss.length) ? ss[i + 1] : null;
  }

  bool get _hasNext => _nextEpisode != null || _nextSeason != null;

  /// Next (season, episode): same season first, else first episode of the
  /// next season (fetched on demand). Null when the series is over.
  Future<(int, int, List<int>?)?> _resolveNext() async {
    final ne = _nextEpisode;
    if (ne != null) return (_season, ne, null);
    final ns = _nextSeason;
    if (ns == null) return null;
    try {
      final eps = await _api.episodes(widget.contentId, ns);
      final nums = eps.map((e) => e.number).where((n) => n > 0).toList()..sort();
      if (nums.isEmpty) return null;
      return (ns, nums.first, nums);
    } catch (_) {
      return null;
    }
  }

  Future<void> _playNext((int, int, List<int>?) n) async {
    _season = n.$1;
    _episode = n.$2;
    if (n.$3 != null) _episodeNumbers = n.$3!;
    await _loadEpisode();
  }

  Future<void> _onFinished() async {
    if (_finishedHandled) return;
    _finishedHandled = true;
    final v = _vc?.value;
    final dur = (v?.duration as Duration?) ?? Duration.zero;
    await Prefs.saveProgress(_pkey, dur.inMilliseconds, dur.inMilliseconds);
    final next = await _resolveNext();
    if (!mounted) return;
    if (next != null && Prefs.autoplayNext) {
      _flash('Next: S${next.$1} E${next.$2}', Icons.skip_next_rounded);
      await _playNext(next);
      return;
    }
    // Not auto-playing: keep the series in Continue Watching as "Up next".
    if (next != null && widget.item != null) {
      await Prefs.markUpNext(widget.item!, widget.contentId, next.$1, next.$2);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _goNext() async {
    final next = await _resolveNext();
    if (next == null || !mounted) return;
    _saveProgress();
    await _playNext(next);
  }

  // --------------------------------------------------------------- controls

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      final playing = (_vc?.value.isPlaying as bool?) ?? false;
      if (mounted && playing) setState(() => _controlsVisible = false);
    });
  }

  void _togglePlay() {
    final c = _bp;
    if (c == null) return;
    final playing = (_vc?.value.isPlaying as bool?) ?? false;
    if (playing) {
      c.pause();
      _saveProgress();
    } else {
      c.play();
    }
    _scheduleHide();
  }

  Future<void> _seekBy(int secs, {bool showHud = true}) async {
    final c = _bp;
    final v = _vc?.value;
    if (c == null || v == null) return;
    final pos = (v.position as Duration?) ?? Duration.zero;
    final dur = (v.duration as Duration?) ?? Duration.zero;
    var t = pos + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur;
    await c.seekTo(t);
    if (showHud) {
      _flash(secs > 0 ? '+${secs}s' : '${secs}s',
          secs > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded);
    }
  }

  void _flash(String text, IconData icon) {
    if (!mounted) return;
    _hudTimer?.cancel();
    setState(() {
      _hudText = text;
      _hudIcon = icon;
    });
    _hudTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _hudText = null);
    });
  }

  // ---- vertical drag: left = brightness, right = volume
  void _onDragUpdate(DragUpdateDetails d, double height) {
    final delta = -d.delta.dy / (height * 0.7);
    if (_dragLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      ScreenBrightness.instance.setScreenBrightness(_brightness).catchError((_) {});
      _flash('${(_brightness * 100).round()}%', Icons.brightness_6_rounded);
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      VolumeController.instance.setVolume(_volume, showSystemUI: false);
      _flash('${(_volume * 100).round()}%',
          _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded);
    }
  }

  // ------------------------------------------------------------------ sheets

  String _streamLabel(int i) {
    final q = _streams[i].quality;
    return q.isNotEmpty ? q : 'Stream ${i + 1}';
  }

  Future<void> _pickQuality() async {
    final idx = await showOptionSheet<int>(
      context,
      title: 'Quality',
      items: [
        for (var i = 0; i < _streams.length; i++) OptionItem(_streamLabel(i), i)
      ],
      selected: _streamIdx,
    );
    if (idx == null || idx == _streamIdx) return;
    final v = _vc?.value;
    final resume = (v?.position as Duration?) ?? Duration.zero;
    setState(() => _loading = true);
    await _disposeController();
    _streamIdx = idx;
    try {
      await _initPlayer(startAt: resume);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickSpeed() async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final s = await showOptionSheet<double>(
      context,
      title: 'Playback speed',
      items: [for (final x in speeds) OptionItem('${x}x', x)],
      selected: _speed,
    );
    if (s == null) return;
    setState(() => _speed = s);
    await _bp?.setSpeed(s);
  }

  Future<void> _pickSubtitle() async {
    final i = await showOptionSheet<int>(
      context,
      title: 'Subtitles',
      items: [
        const OptionItem('Off', -1),
        for (var k = 0; k < _captions.length; k++)
          OptionItem(
              _captions[k].language.isEmpty
                  ? 'Track ${k + 1}'
                  : _captions[k].language,
              k),
      ],
      selected: _capIdx,
    );
    if (i == null || i == _capIdx) return;
    if (i == -1) {
      setState(() {
        _capIdx = -1;
        _cues = [];
      });
      return;
    }
    try {
      final res = await http
          .get(Uri.parse(_captions[i].url),
              headers: _streams.isNotEmpty ? _streams[_streamIdx].headers : {})
          .timeout(const Duration(seconds: 20));
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      final cues = SrtParser.parse(text);
      if (!mounted) return;
      setState(() {
        _capIdx = i;
        _cues = cues;
      });
      if (cues.isEmpty) _flash('Subtitle empty', Icons.subtitles_off_outlined);
    } catch (_) {
      _flash('Could not load subtitle', Icons.error_outline_rounded);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveProgress(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Stack(children: [
        ErrorRetry(message: _error!, onRetry: _retry),
        if (_streams.length > 1)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: _pickQuality,
                icon: const Icon(Icons.hd_outlined, color: AppColors.gold),
                label: const Text('Choose quality',
                    style: TextStyle(color: AppColors.gold)),
              ),
            ),
          ),
        Positioned(
          top: 12,
          left: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ]);
    }
    if (_loading || _bp == null || _vc == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    return LayoutBuilder(builder: (context, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (d) => _dtPos = d.localPosition,
        onDoubleTap: () => _seekBy(_dtPos.dx < box.maxWidth / 2 ? -10 : 10),
        onVerticalDragStart: (d) => _dragLeft = d.localPosition.dx < box.maxWidth / 2,
        onVerticalDragUpdate: (d) => _onDragUpdate(d, box.maxHeight),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: BetterPlayer(controller: _bp!)),
            _subtitleOverlay(),
            if (_hudText != null) _hud(),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: PlayerControls(
                  vc: _vc!,
                  title: _displayTitle,
                  speedLabel: '${_speed}x',
                  hasQuality: _streams.length > 1,
                  hasSubtitles: _captions.isNotEmpty,
                  onBack: () => Navigator.pop(context),
                  onTogglePlay: _togglePlay,
                  onSeekBy: (s) => _seekBy(s, showHud: false),
                  onSeekTo: (d) {
                    _bp?.seekTo(d);
                    _scheduleHide();
                  },
                  onSpeed: _pickSpeed,
                  onQuality: _pickQuality,
                  onSubtitles: _pickSubtitle,
                  onNext: _hasNext ? _goNext : null,
                  onInteract: _scheduleHide,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _subtitleOverlay() {
    final vc = _vc;
    if (vc == null || _cues.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 40,
      right: 40,
      bottom: _controlsVisible ? 84 : 28,
      child: IgnorePointer(
        child: ValueListenableBuilder<dynamic>(
          valueListenable: vc,
          builder: (_, v, __) {
            final pos = (v.position as Duration?) ?? Duration.zero;
            final cue = SrtParser.at(_cues, pos);
            if (cue == null) return const SizedBox.shrink();
            return Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Prefs.subtitleBg
                      ? Colors.black.withOpacity(0.55)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cue.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Prefs.subtitleSize,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(Prefs.subtitleColor),
                    shadows: Prefs.subtitleBg
                        ? null
                        : const [
                            Shadow(blurRadius: 4, color: Colors.black),
                            Shadow(blurRadius: 8, color: Colors.black),
                          ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hud() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_hudIcon, color: AppColors.gold),
            const SizedBox(width: 10),
            Text(_hudText!,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _saveTimer?.cancel();
    _bp?.removeEventsListener(_onPlayerEvent);
    _bp?.dispose(forceDispose: true);
    ScreenBrightness.instance.resetScreenBrightness().catchError((_) {});
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
