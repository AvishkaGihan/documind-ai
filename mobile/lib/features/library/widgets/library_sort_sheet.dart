import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

enum LibrarySortMode { date, name, status }

/// Shows a redesigned sort bottom sheet with horizontal chip selectors.
///
/// Returns the selected [LibrarySortMode] or `null` if dismissed.
Future<LibrarySortMode?> showLibrarySortSheet(
  BuildContext context,
  LibrarySortMode currentMode,
) {
  final tokens = Theme.of(context).extension<DocuMindTokens>()!;

  return showModalBottomSheet<LibrarySortMode>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _SortSheetContent(
        currentMode: currentMode,
        tokens: tokens,
      );
    },
  );
}

class _SortSheetContent extends StatelessWidget {
  const _SortSheetContent({
    required this.currentMode,
    required this.tokens,
  });

  final LibrarySortMode currentMode;
  final DocuMindTokens tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: tokens.colors.borderDefault.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.colors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Section header
              Text(
                'Sort by',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Chip selector row
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _SortChip(
                    key: const Key('library-sort-date'),
                    icon: Icons.schedule_rounded,
                    label: 'Newest first',
                    isSelected: currentMode == LibrarySortMode.date,
                    onTap: () =>
                        Navigator.of(context).pop(LibrarySortMode.date),
                    tokens: tokens,
                  ),
                  _SortChip(
                    key: const Key('library-sort-name'),
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'A → Z',
                    isSelected: currentMode == LibrarySortMode.name,
                    onTap: () =>
                        Navigator.of(context).pop(LibrarySortMode.name),
                    tokens: tokens,
                  ),
                  _SortChip(
                    key: const Key('library-sort-status'),
                    icon: Icons.tune_rounded,
                    label: 'Status',
                    isSelected: currentMode == LibrarySortMode.status,
                    onTap: () =>
                        Navigator.of(context).pop(LibrarySortMode.status),
                    tokens: tokens,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final DocuMindTokens tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.colors.accentPrimary
                : tokens.colors.surfaceTertiary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? tokens.colors.accentPrimary
                  : tokens.colors.borderDefault.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? tokens.colors.textOnAccent
                    : tokens.colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? tokens.colors.textOnAccent
                      : tokens.colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: tokens.colors.textOnAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
