import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/settings/providers/theme_mode_provider.dart';
import 'package:documind_ai/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocuMindApp extends StatelessWidget {
  const DocuMindApp({
    super.key,
    this.initialLocation,
    this.overrides = const [],
  });

  final String? initialLocation;
  final List overrides;

  @override
  Widget build(BuildContext context) {
    final resolvedOverrides = List.of(overrides);
    if (initialLocation != null) {
      resolvedOverrides.add(
        initialLocationProvider.overrideWithValue(initialLocation!),
      );
    }

    return ProviderScope(
      overrides: resolvedOverrides.cast(),
      child: const _DocuMindRoot(),
    );
  }
}

class _DocuMindRoot extends ConsumerWidget {
  const _DocuMindRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'DocuMind AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
