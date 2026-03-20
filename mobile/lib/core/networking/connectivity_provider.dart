import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityState {
  const ConnectivityState({required this.isOnline, required this.types});

  final bool isOnline;
  final Set<ConnectivityResult> types;
}

abstract class ConnectivityService {
  bool get isOnline;
  Stream<bool> get onlineChanges;
}

class ConnectivityMonitor implements ConnectivityService {
  ConnectivityMonitor(this._connectivity) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final nextOnline = _isOnlineFrom(results);
      _isOnline = nextOnline;
      _controller.add(nextOnline);
    });
    unawaited(_bootstrap());
  }

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  Future<void> _bootstrap() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _isOnlineFrom(initial);
    } on MissingPluginException {
      _isOnline = true;
    } catch (_) {
      _isOnline = true;
    }
  }

  bool _isOnlineFrom(List<ConnectivityResult> types) {
    return types.any((type) => type != ConnectivityResult.none);
  }

  void dispose() {
    if (_subscription != null) {
      try {
        unawaited(_subscription!.cancel());
      } catch (_) {
        // Best effort cleanup for test environments without platform channels.
      }
    }
    _subscription = null;
    try {
      unawaited(_controller.close());
    } catch (_) {
      // Ignore close failures in synthetic test environments.
    }
  }
}

final connectivityPackageProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final monitor = ConnectivityMonitor(ref.watch(connectivityPackageProvider));
  ref.onDispose(monitor.dispose);
  return monitor;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnline;
});

final connectivityChangesProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineChanges;
});
