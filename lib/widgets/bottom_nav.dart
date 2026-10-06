import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class GlassBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassBottomNav({super.key, required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.bookmark_rounded, 'My List'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.6)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => onChanged(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_items[i].$1,
                                size: 24,
                                color: i == index
                                    ? AppColors.gold
                                    : AppColors.textSecondary),
                            const SizedBox(height: 3),
                            Text(_items[i].$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: i == index
                                        ? AppColors.gold
                                        : AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
