import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/content_filter.dart';
import '../../core/api/models.dart';
import '../../core/api/moviebox_client.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/loading.dart';
import '../../widgets/poster_card.dart';
import '../details/details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = MovieBoxClient.shared;
  final _controller = TextEditingController();
  Timer? _debounce;

  static const _genres = [
    'Action', 'Comedy', 'Drama', 'Thriller', 'Horror',
    'Romance', 'Sci-Fi', 'Animation', 'Crime', 'Fantasy',
  ];

  String _query = '';
  String? _genre;
  bool _loading = false;
  String? _error;
  List<TitleItem> _raw = []; // unfiltered; filter applied in build
  List<TitleItem> get _results => ContentFilter.apply(_raw);

  void _onFilter() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Prefs.filterRev.addListener(_onFilter);
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _genre = null;
      _run(v.trim());
    });
    setState(() {});
  }

  Future<void> _run(String q) async {
    _query = q;
    if (q.isEmpty) {
      setState(() {
        _raw = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.search(q, perPage: 30);
      if (!mounted || q != _query) return;
      setState(() {
        _raw = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || q != _query) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _pickGenre(String g) {
    _debounce?.cancel(); // a pending typed query must not override the genre
    FocusScope.of(context).unfocus();
    final selected = _genre == g;
    setState(() => _genre = selected ? null : g);
    if (selected) {
      _run(_controller.text.trim());
    } else {
      _controller.clear();
      _run(g);
    }
  }

  void _open(TitleItem t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(item: t)),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    Prefs.filterRev.removeListener(_onFilter);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Search',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Movies, series…',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          _genre = null;
                          _run('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = _genres[i];
                final sel = _genre == g;
                return GestureDetector(
                  onTap: () => _pickGenre(g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.gold : AppColors.glass,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(g,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.black : Colors.white)),
                  ),
                );
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
        gridDelegate: _grid,
        itemCount: 9,
        itemBuilder: (_, __) => const ShimmerBox(),
      );
    }
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: () => _run(_query));
    }
    if (_query.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find something to watch',
        hint: 'Search for a movie or series, or pick a genre.',
      );
    }
    final results = _results;
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results for "$_query"',
        hint: 'Check the spelling or try a different title.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: kPosterGrid,
      itemCount: results.length,
      itemBuilder: (_, i) => LayoutBuilder(
        builder: (_, c) => PosterCard(
            item: results[i], width: c.maxWidth, onTap: () => _open(results[i])),
      ),
    );
  }

  static const _grid = kPosterGrid;
}
