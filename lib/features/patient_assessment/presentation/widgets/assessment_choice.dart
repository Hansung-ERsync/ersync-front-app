import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AssessmentChoice extends StatelessWidget {
  const AssessmentChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primary,
    this.selectedForegroundColor = AppColors.textOnDark,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedForegroundColor;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget control = Material(
      color: selected ? selectedColor : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? selectedColor : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? selectedForegroundColor
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Widget semantics = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: control,
    );
    return expand ? Expanded(child: semantics) : semantics;
  }
}
