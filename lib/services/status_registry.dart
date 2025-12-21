import 'dart:async';
import 'package:flutter/material.dart';

class StatusRegistry extends ChangeNotifier {
  String _message = '';
  Color _color = Colors.grey;
  Timer? _clearTimer;

  String get message => _message;
  Color get color => _color;

  void setStatus(String msg, Color color, {Duration duration = const Duration(seconds: 8)}) {
    _clearTimer?.cancel();
    _message = msg;
    _color = color;
    notifyListeners();

    _clearTimer = Timer(duration, () {
      _message = '';
      _color = Colors.grey;
      notifyListeners();
    });
  }

  void clear() {
    _clearTimer?.cancel();
    _message = '';
    _color = Colors.grey;
    notifyListeners();
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}
