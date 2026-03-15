import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: tokens.colors.surfaceSecondary,
          indicatorColor: tokens.colors.accentPrimary.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
            final baseStyle = theme.textTheme.labelSmall;
            if (states.contains(WidgetState.selected)) {
              return baseStyle?.copyWith(color: tokens.colors.accentPrimary);
            }
            return baseStyle?.copyWith(color: tokens.colors.textSecondary);
          }),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            _destination(
              context: context,
              label: 'Library',
              emoji: '📚',
              selectedColor: tokens.colors.accentPrimary,
              unselectedColor: tokens.colors.textSecondary,
            ),
            _destination(
              context: context,
              label: 'Chat',
              emoji: '💬',
              selectedColor: tokens.colors.accentPrimary,
              unselectedColor: tokens.colors.textSecondary,
            ),
            _destination(
              context: context,
              label: 'Settings',
              emoji: '⚙️',
              selectedColor: tokens.colors.accentPrimary,
              unselectedColor: tokens.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _destination({
    required BuildContext context,
    required String label,
    required String emoji,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return NavigationDestination(
      icon: _destinationIcon(context, emoji, unselectedColor),
      selectedIcon: _destinationIcon(context, emoji, selectedColor),
      label: label,
    );
  }

  Widget _destinationIcon(BuildContext context, String emoji, Color color) {
    final iconStyle = Theme.of(context).textTheme.titleLarge;

    return SizedBox.square(
      dimension: 44,
      child: Center(
        child: Text(emoji, style: iconStyle?.copyWith(color: color)),
      ),
    );
  }
}
