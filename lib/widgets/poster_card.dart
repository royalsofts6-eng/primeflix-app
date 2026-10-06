import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/api/models.dart';
import '../core/theme/app_theme.dart';
import 'loading.dart';

class PosterCard extends StatelessWidget {
  final TitleItem item;
  final double width;
  final VoidCallback? onTap;

  const PosterCard({super.key, required this.item, this.width = 120, this.onTap});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: width,
                height: height,
                child: item.poster.isEmpty
                    ? Container(
                        color: AppColors.glass,
                        alignment: Alignment.center,
                        child: const Icon(Icons.movie_outlined,
                            color: AppColors.textSecondary))
                    : CachedNetworkImage(
                        imageUrl: item.poster,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) =>
                            ShimmerBox(width: width, height: height),
                        errorWidget: (_, __, ___) => Container(
                            color: AppColors.glass,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined,
                                color: AppColors.textSecondary)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (item.year.isNotEmpty)
              Text(item.year, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Shared 3-column poster grid (extra height so large system fonts don't overflow).
const kPosterGrid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 12,
  mainAxisSpacing: 14,
  childAspectRatio: 0.46,
);
