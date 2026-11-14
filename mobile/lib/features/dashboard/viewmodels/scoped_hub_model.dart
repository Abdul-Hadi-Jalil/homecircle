import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../repositories/hub_repository.dart';

abstract class ScopedHubModel extends ChangeNotifier {
  ScopedHubModel(this.repository, this.session) {
    session.addListener(scopeChanged);
    scopeChanged();
  }
  final HubRepository repository;
  final SessionViewModel session;
  String scope = '', user = '', home = '';
  bool disposed = false,
      opened = false,
      loading = false,
      busy = false,
      cached = false,
      cacheError = false;
  String? error;
  DateTime? savedAt;
  int request = 0;
  Timer? refreshTimer;
  bool get ready =>
      !disposed &&
      session.stage == ApplicationStage.householdReady &&
      home.isNotEmpty;
  bool current(String captured) => ready && scope == captured;
  void emit() {
    if (!disposed) notifyListeners();
  }

  void reset();
  Future<void> load();
  void scopeChanged() {
    final next =
        '${session.user?.id}:${session.activeHousehold?.id}:${session.scopeRevision}';
    if (next == scope) return;
    final previous = user, oldHome = home;
    scope = next;
    user = session.user?.id ?? '';
    home = session.activeHousehold?.id ?? '';
    request++;
    loading = busy = cached = cacheError = false;
    error = null;
    savedAt = null;
    reset();
    refreshTimer?.cancel();
    if (previous.isNotEmpty && previous != user) {
      unawaited(repository.cache.clearUser(previous).catchError((_) {}));
    } else if (previous.isNotEmpty &&
        oldHome.isNotEmpty &&
        !session.restoring &&
        !session.switching &&
        !session.households.any((h) => h.id == oldHome)) {
      unawaited(
        repository.cache.clearHousehold(previous, oldHome).catchError((_) {}),
      );
    }
    emit();
    if (ready && opened) {
      unawaited(load());
      startTimer();
    }
  }

  Future<void> open() async {
    opened = true;
    startTimer();
    await load();
  }

  void startTimer() {
    refreshTimer?.cancel();
    if (ready) {
      refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (ready && !loading && !busy) unawaited(load());
      });
    }
  }

  void failed(Object e) {
    error = e is AppException ? e.code : 'unknown';
    if (e is UnauthorizedException ||
        e is ForbiddenException ||
        e is NotFoundException) {
      reset();
      cached = false;
      savedAt = null;
      opened = false;
      refreshTimer?.cancel();
      unawaited(repository.cache.clearHousehold(user, home).catchError((_) {}));
    }
  }

  void adopt(HubRead value) {
    cached = value.cached;
    cacheError = value.cacheError;
    savedAt = value.savedAt;
  }

  @override
  void dispose() {
    disposed = true;
    request++;
    refreshTimer?.cancel();
    session.removeListener(scopeChanged);
    super.dispose();
  }
}
