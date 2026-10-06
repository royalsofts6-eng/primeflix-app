import 'package:flutter/material.dart';
import '../../widgets/loading.dart';
import '../../core/api/models.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/poster_card.dart';
import '../details/details_screen.dart';

/// Saved titles grid. Tap = open, (x) button or long-press = remove.
class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  late List<TitleItem> _items = Prefs.myList;

  Future<void> _open(TitleItem t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(item: t)),
    );
    if (mounted) setState(() => _items = Prefs.myList);
  }

  Future<void> _remove(TitleItem t) async {
    await Prefs.toggleMyList(t);
    if (mounted) setState(() => _items = Prefs.myList);
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
            child: Text('My List',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _items.isEmpty
                ? const EmptyState(
                    icon: Icons.bookmark_add_outlined,
                    title: 'Your list is empty',
                    hint: 'Tap + My List on any title to save it here.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                    gridDelegate: kPosterGrid,
                    itemCount: _items.length,
                    itemBuilder: (_, i) => LayoutBuilder(
                      builder: (_, c) => GestureDetector(
                        onLongPress: () => _remove(_items[i]),
                        child: Stack(
                          children: [
                            PosterCard(
                              item: _items[i],
                              width: c.maxWidth,
                              onTap: () => _open(_items[i]),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _remove(_items[i]),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
