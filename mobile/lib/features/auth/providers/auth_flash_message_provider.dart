import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthFlashMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

final authFlashMessageProvider =
    NotifierProvider<AuthFlashMessageNotifier, String?>(
      AuthFlashMessageNotifier.new,
    );
