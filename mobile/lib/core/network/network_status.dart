import 'package:flutter/foundation.dart';

class NetworkStatus extends ChangeNotifier {
  bool _offline = false;
  bool _disposed = false;
  bool get offline => _offline;

  void record({required bool reachable}) {
    if (_disposed) return;
    if (_offline == !reachable) return;
    _offline = !reachable;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
