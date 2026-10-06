import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/api/content_filter.dart';
import '../../core/api/models.dart';
import '../../core/api/moviebox_client.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass.dart';
import '../../widgets/loading.dart';
import '../home/widgets/title_row.dart';
import '../player/play_launcher.dart';
import 'widgets/dub_sheet.dart';

class DetailsScreen extends StatefulWidget {
  final TitleItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _api = MovieBoxClient.shared;

  late TitleItem _item = widget.item;
  late String _activeId = widget.item.id; // changes when a dub is selected

  List<DubOption> _dubs = [];
  List<int> _seasons = [];
  int _season = 1;
  List<Episode> _episodes = [];
  List<TitleItem> _related = [];

  bool _loading = true;
  bool _episodesLoading = false;
  String? _error;
  bool _inList = false;

  @override
  void initState() {
    super.initState();
    _inList = Prefs.inMyList(_item.id);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        final info = await _api.info(widget.item.id);
        _item = _item.merge(info);
      } catch (_) {
        // We already have the basics (from the list/search); only fail
        // when there is nothing usable to show.
        if (_item.title.isEmpty) rethrow;
      }
      _inList = Prefs.inMyList(_item.id);

      // Optional extras: failures here must not break the screen.
      _dubs = await _api.dubs(widget.item.id).catchError((_) => <DubOption>[]);
      _loadRelated();

      if (_item.isSeries) {
        await _loadSeasons(_activeId);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSeasons(String id) async {
    final seasons = await _api.seasons(id).catchError((_) => <int>[]);
    _seasons = seasons.isEmpty ? [1] : seasons;
    _season = _seasons.first;
    await _loadEpisodes(id, _season);
  }

  Future<void> _loadEpisodes(String id, int season) async {
    if (mounted) setState(() => _episodesLoading = true);
    try {
      final eps = await _api.episodes(id, season);
      _episodes = eps;
    } catch (_) {
      _episodes = [];
    }
    if (mounted) setState(() => _episodesLoading = false);
  }

  Future<void> _loadRelated() async {
    try {
      final firstGenre = _item.genre.split(',').first.trim();
      final q = firstGenre.isNotEmpty ? firstGenre : _item.title;
      final r = await _api.search(q, perPage: 14);
      if (!mounted) return;
      setState(() => _related = ContentFilter.apply(r)
          .where((t) => t.id != _item.id)
          .toList());
    } catch (_) {}
  }

  Future<void> _pickDub() async {
    final d = await showDubSheet(context, dubs: _dubs, activeId: _activeId);
    if (d == null || d.id == _activeId) return;
    setState(() {
      _activeId = d.id;
      _loading = true;
    });
    try {
      if (_item.isSeries) await _loadSeasons(_activeId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleList() async {
    final added = await Prefs.toggleMyList(_item);
    if (!mounted) return;
    setState(() => _inList = added);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      content: Text(added ? 'Added to My List' : 'Removed from My List'),
    ));
  }

  Future<void> _play({int season = 0, int episode = 0}) async {
    await launchPlayer(
      context,
      item: _item,
      contentId: _activeId,
      season: season,
      episode: episode,
      episodeNumbers: _episodes.map((e) => e.number).toList(),
      seasons: _seasons,
    );
    if (mounted) setState(() {}); // refresh episode progress bars
  }

  double _epProgress(int ep) => Prefs.progressFraction(
      Prefs.progressKey(_activeId, _season, ep));

  void _openRelated(TitleItem t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(item: t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error != null
          ? SafeArea(child: ErrorRetry(message: _error!, onRetry: _load))
          : CustomScrollView(
              slivers: [
                _header(),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.gold)),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _body(),
                      if (_item.isSeries) _episodesSection(),
                      TitleRow(
                          heading: 'More like this',
                          items: _related,
                          onTap: _openRelated),
                      const SizedBox(height: 40),
                    ]),
                  ),
              ],
            ),
    );
  }

  Widget _header() {
    final img = _item.backdrop.isNotEmpty ? _item.backdrop : _item.poster;
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black45,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (img.isNotEmpty)
              CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ShimmerBox(radius: 0),
                errorWidget: (_, __, ___) => Container(color: AppColors.glass),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [Colors.transparent, AppColors.background],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final meta = [
      if (_item.year.isNotEmpty) _item.year,
      if (_item.isSeries) 'Series' else 'Movie',
      if (_item.genre.isNotEmpty) _item.genre,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_item.title,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_item.rating > 0) ...[
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 4),
                Text(_item.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(meta,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (!_item.isSeries)
                Expanded(
                  child: GoldButton(label: '▶  Play', onPressed: () => _play()),
                ),
              if (!_item.isSeries) const SizedBox(width: 12),
              _roundButton(
                icon: _inList ? Icons.check_rounded : Icons.add_rounded,
                label: _inList ? 'In List' : 'My List',
                onTap: _toggleList,
              ),
              if (_dubs.length > 1) ...[
                const SizedBox(width: 12),
                _roundButton(
                  icon: Icons.translate_rounded,
                  label: 'Dub',
                  onTap: _pickDub,
                ),
              ],
            ],
          ),
          if (_item.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(_item.description,
                style: const TextStyle(
                    fontSize: 15, height: 1.45, color: Color(0xFFD0D0D8))),
          ],
        ],
      ),
    );
  }

  Widget _roundButton(
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        radius: 14,
        blur: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _episodesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Episodes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _seasons[i];
                final sel = s == _season;
                return GestureDetector(
                  onTap: () {
                    if (sel) return;
                    setState(() => _season = s);
                    _loadEpisodes(_activeId, s);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.gold : AppColors.glass,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Season $s',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.black : Colors.white)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_episodesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else if (_episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No episodes found for this season',
                  style: Theme.of(context).textTheme.bodySmall),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _episodes.length,
              itemBuilder: (_, i) {
                final e = _episodes[i];
                return GestureDetector(
                  onTap: () => _play(season: _season, episode: e.number),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text('${e.number}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (_epProgress(e.number) > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: _epProgress(e.number),
                              minHeight: 3,
                              color: AppColors.gold,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
