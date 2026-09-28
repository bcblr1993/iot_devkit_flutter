import 'dart:async';
import 'package:flutter/foundation.dart';

class StatusRegistry extends ChangeNotifier {
  String _message = '';
  Timer? _clearTimer;

  String get message => _message;

  void setStatus(String msg, {Duration duration = const Duration(seconds: 8)}) {
    _clearTimer?.cancel();
    _message = msg;
    notifyListeners();

    _clearTimer = Timer(duration, () {
      _message = '';
      notifyListeners();
    });
  }

  void clear() {
    _clearTimer?.cancel();
    _message = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}
