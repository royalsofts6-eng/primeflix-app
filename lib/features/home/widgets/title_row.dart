import 'package:flutter/material.dart';
import '../../../core/api/models.dart';
import '../../../widgets/poster_card.dart';

class TitleRow extends StatelessWidget {
  final String heading;
  final List<TitleItem> items;
  final ValueChanged<TitleItem>? onTap;

  const TitleRow({super.key, required this.heading, required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(heading,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 120 * 1.5 + 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                PosterCard(item: items[i], onTap: () => onTap?.call(items[i])),
          ),
        ),
      ],
    );
  }
}
