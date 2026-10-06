import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';
import '../../../widgets/loading.dart';

class HeroCarousel extends StatefulWidget {
  final List<TitleItem> items;
  final ValueChanged<TitleItem>? onTap;

  const HeroCarousel({super.key, required this.items, this.onTap});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || widget.items.length < 2) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.55;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) {
              final t = widget.items[i];
              final img = t.backdrop.isNotEmpty ? t.backdrop : t.poster;
              return GestureDetector(
                onTap: () => widget.onTap?.call(t),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ShimmerBox(radius: 0),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.glass),
                      ),
                    // Gradient overlay (not solid)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1],
                          colors: [Colors.transparent, AppColors.background],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 36,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            [t.year, t.genre]
                                .where((e) => e.isNotEmpty)
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 140,
                            child: GoldButton(
                                label: 'Details',
                                onPressed: () => widget.onTap?.call(t)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.gold
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
