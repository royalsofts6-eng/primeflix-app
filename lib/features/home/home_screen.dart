import 'package:flutter/material.dart';
import '../../core/api/content_filter.dart';
import '../../core/api/models.dart';
import '../../core/api/moviebox_client.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/loading.dart';
import '../details/details_screen.dart';
import '../player/play_launcher.dart';
import 'widgets/continue_row.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/title_row.dart';

/// Home: auto-scrolling hero (trending) + horizontal rows.
/// The wrapper API only exposes /search, so rows are built from search queries.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = MovieBoxClient.shared;

  // heading -> search query
  static const _rows = {
    'Movies': 'movie',
    'Series': 'series',
    'Hindi Dubbed': 'hindi dubbed',
  };

  // Raw (unfiltered) data: the family filter is applied in build() so that
  // toggling it in Settings takes effect immediately.
  _HomeData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<TitleItem>> _safe(Future<List<TitleItem>> f) =>
      f.catchError((_) => <TitleItem>[]);

  /// Loads everything. Keeps showing old data while refreshing; only shows
  /// the error screen when there is nothing to show.
  Future<void> _load() async {
    final first = _data == null;
    if (first) setState(() => _loading = true);
    try {
      // Every future is wrapped so a failure can never become an
      // unhandled async error.
      final trendingF = _api.search('trending', perPage: 8);
      final rowFs = {
        for (final e in _rows.entries)
          e.key: _safe(_api.search(e.value, perPage: 12))
      };
      final trending = await trendingF;
      final rows = <String, List<TitleItem>>{};
      for (final e in rowFs.entries) {
        rows[e.key] = await e.value;
      }
      if (!mounted) return;
      setState(() {
        _data = _HomeData(trending, rows);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      // Drain the row futures (already error-safe) and report.
      if (!mounted) return;
      setState(() {
        if (_data == null) _error = e.toString();
        _loading = false;
      });
    }
  }

  void _open(TitleItem t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(item: t)),
    );
  }

  /// Resume a Continue Watching entry directly in the player.
  Future<void> _resume(WatchEntry e) async {
    var eps = <int>[];
    var seasons = <int>[];
    if (e.item.isSeries && e.season > 0) {
      try {
        final list = await _api.episodes(e.contentId, e.season);
        eps = list.map((x) => x.number).toList();
        seasons = await _api.seasons(e.contentId);
      } catch (_) {
        // Autoplay-next is optional; still resume.
      }
    }
    if (!mounted) return;
    await launchPlayer(
      context,
      item: e.item,
      contentId: e.contentId,
      season: e.season,
      episode: e.episode,
      episodeNumbers: eps,
      seasons: seasons,
      askResume: false, // tapping the card already means "resume"
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const _HomeSkeleton();
    if (_data == null) {
      return ErrorRetry(message: _error ?? 'Could not load.', onRetry: _load);
    }
    return ValueListenableBuilder<int>(
      valueListenable: Prefs.filterRev,
      builder: (context, _, __) {
        final d = _data!;
        final trending = ContentFilter.apply(d.trending);
        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.background,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (trending.isNotEmpty)
                HeroCarousel(
                    key: ValueKey(trending.length),
                    items: trending.take(6).toList(),
                    onTap: _open),
              ContinueRow(onTap: _resume),
              for (final e in d.rows.entries)
                TitleRow(
                    heading: e.key,
                    items: ContentFilter.apply(e.value),
                    onTap: _open),
              if (trending.isEmpty && d.rows.values.every((l) => l.isEmpty))
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: EmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: 'Nothing to show yet',
                    hint: 'Pull down to refresh.',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  final List<TitleItem> trending;
  final Map<String, List<TitleItem>> rows;
  _HomeData(this.trending, this.rows);
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ShimmerBox(height: MediaQuery.of(context).size.height * 0.5, radius: 0),
        for (var r = 0; r < 2; r++) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: ShimmerBox(width: 120, height: 20, radius: 6),
          ),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) =>
                  const ShimmerBox(width: 120, height: 180),
            ),
          ),
        ],
      ],
    );
  }
}
