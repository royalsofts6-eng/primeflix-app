import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';

/// Glassmorphic bottom sheet to pick a dub / audio language.
/// Returns the chosen [DubOption] (or null if dismissed).
Future<DubOption?> showDubSheet(
  BuildContext context, {
  required List<DubOption> dubs,
  required String activeId,
}) {
  return showModalBottomSheet<DubOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Audio / Dub',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final d in dubs)
                          ListTile(
                            title: Text(d.language.isEmpty ? 'Original' : d.language),
                            trailing: d.id == activeId
                                ? const Icon(Icons.check_rounded,
                                    color: AppColors.gold)
                                : null,
                            onTap: () => Navigator.pop(ctx, d),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
