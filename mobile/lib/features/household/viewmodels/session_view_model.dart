import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/models/auth_identity.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/household.dart';
import '../repositories/household_repository.dart';
import '../services/realtime_scope.dart';

enum ApplicationStage {
  bootstrapping,
  unauthenticated,
  pendingEmailVerification,
  loadingMemberships,
  noHousehold,
  householdReady,
  authenticationError,
  recovery,
}

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this.auth,
    required this.repository,
    required this.store,
    required this.realtime,
    this.loadProfile,
  });
  final AuthRepository auth;
  final HouseholdRepository repository;
  final LocalStore store;
  final RealtimeScope realtime;
  final Future<Map<String, dynamic>> Function()? loadProfile;
  Map<String, dynamic>? profile;
  StreamSubscription<AuthIdentity?>? _subscription;
  AuthIdentity? user;
  List<Household> households = const [];
  Household? activeHousehold;
  bool restoring = true;
  bool switching = false;
  bool passwordRecovery = false;
  String? errorCode;
  int scopeRevision = 0;
  int _generation = 0;
  bool _disposed = false;
  String? pendingEmail;
  bool authCallbackError = false;
  bool inviteAfterCreate = false;
  bool loggedOut = false;
  bool get onboardingCompleted =>
      store.preferences.getBool('homecircle.onboardingComplete') ?? false;
  ApplicationStage get stage {
    if (restoring || switching) {
      return user == null
          ? ApplicationStage.bootstrapping
          : ApplicationStage.loadingMemberships;
    }
    if (authCallbackError) return ApplicationStage.authenticationError;
    if (passwordRecovery) return ApplicationStage.recovery;
    if (user == null) {
      return pendingEmail == null
          ? ApplicationStage.unauthenticated
          : ApplicationStage.pendingEmailVerification;
    }
    return activeHousehold == null
        ? ApplicationStage.noHousehold
        : ApplicationStage.householdReady;
  }

  Future<void> completeOnboarding() async {
    await store.preferences.setBool('homecircle.onboardingComplete', true);
    _notify();
  }

  void awaitVerification(String email) {
    pendingEmail = email.trim();
    _notify();
  }

  void dismissAuthNotice() {
    pendingEmail = null;
    authCallbackError = false;
    _notify();
  }

  void finishInvitation() {
    inviteAfterCreate = false;
    _notify();
  }

  Future<void> start() async {
    _subscription = auth.changes.listen(
      (identity) {
        authCallbackError = false;
        if (identity != null) {
          pendingEmail = null;
          loggedOut = false;
        }
        if (identity?.passwordRecovery == true) {
          passwordRecovery = true;
          _notify();
        }
        if (identity?.id != user?.id) unawaited(_restore(identity));
      },
      onError: (Object error) {
        authCallbackError = true;
        errorCode = 'auth';
        restoring = false;
        _notify();
      },
    );
    try {
      await _restore(await auth.restore());
    } on Object {
      restoring = false;
      errorCode = 'auth';
      _notify();
    }
  }

  Future<void> _restore(AuthIdentity? identity) async {
    final generation = ++_generation;
    final previous = user;
    user = identity;
    profile = null;
    restoring = true;
    activeHousehold = null;
    households = const [];
    errorCode = null;
    scopeRevision++;
    _notify();
    try {
      await realtime.switchTo(null);
      if (previous != null && previous.id != identity?.id) {
        await store.clearUser(previous.id);
      }
      if (identity == null) {
        passwordRecovery = false;
        return;
      }
      final loadedProfile = await loadProfile?.call();
      if (!_current(generation)) return;
      profile = loadedProfile;
      final memberships = await repository.memberships();
      if (!_current(generation)) return;
      households = List.unmodifiable(memberships);
      await store.retainHouseholds(
        identity.id,
        memberships.map((item) => item.id).toSet(),
      );
      if (!_current(generation)) return;
      final preferred = store.activeHousehold(identity.id);
      Household? selected;
      for (final household in households) {
        if (household.id == preferred) selected = household;
      }
      selected ??= households.length == 1 ? households.first : null;
      await _activate(selected, generation);
    } on AppException catch (error) {
      if (_current(generation)) errorCode = error.code;
    } on Object {
      if (_current(generation)) errorCode = 'unknown';
    } finally {
      if (_current(generation)) {
        restoring = false;
        switching = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => _restore(user);

  Future<void> selectHousehold(
    String householdId, {
    bool inviteAfterCreation = false,
  }) async {
    if (user == null || switching || restoring) return;
    final generation = ++_generation;
    inviteAfterCreate = inviteAfterCreation;
    switching = true;
    activeHousehold = null;
    errorCode = null;
    scopeRevision++;
    _notify();
    try {
      await realtime.switchTo(null);
      final memberships = await repository.memberships();
      if (!_current(generation)) return;
      households = List.unmodifiable(memberships);
      await store.retainHouseholds(
        user!.id,
        memberships.map((item) => item.id).toSet(),
      );
      if (!_current(generation)) return;
      final selected = households
          .where((item) => item.id == householdId)
          .firstOrNull;
      await _activate(selected, generation);
      if (selected == null) errorCode = 'forbidden';
    } on AppException catch (error) {
      if (_current(generation)) errorCode = error.code;
    } on Object {
      if (_current(generation)) errorCode = 'unknown';
    } finally {
      if (_current(generation)) {
        switching = false;
        _notify();
      }
    }
  }

  Future<void> createHousehold(String name, {String? description}) async {
    if (switching || restoring || user == null) return;
    switching = true;
    errorCode = null;
    _notify();
    final generation = _generation;
    try {
      final created = await repository.create(name, description);
      if (!_current(generation)) return;
      switching = false;
      await selectHousehold(created.id, inviteAfterCreation: true);
    } on AppException catch (error) {
      if (_current(generation)) errorCode = error.code;
    } on Object {
      if (_current(generation)) errorCode = 'unknown';
    } finally {
      if (_current(generation)) {
        switching = false;
        _notify();
      }
    }
  }

  Future<void> _activate(Household? next, int generation) async {
    if (!_current(generation) || user == null) return;
    final userId = user!.id;
    if (next != null) {
      final householdId = next.id;
      try {
        next = await repository.getHousehold(householdId);
      } on AppException catch (error) {
        if (_current(generation) &&
            (error is NotFoundException || error is ForbiddenException)) {
          await store.clearHousehold(userId, householdId);
          await store.setActiveHousehold(userId, null);
        }
        rethrow;
      }
      if (!_current(generation)) return;
    }
    await store.setActiveHousehold(userId, next?.id);
    if (!_current(generation)) return;
    await realtime.switchTo(next?.id);
    if (!_current(generation)) return;
    activeHousehold = next;
    if (next != null) {
      await store.cache(userId, next.id, 'household', next.toJson());
    }
  }

  void completePasswordRecovery() {
    passwordRecovery = false;
    _notify();
  }

  Future<void> logout() async {
    // Clear private state locally even if the remote logout request fails offline.
    final previous = user;
    loggedOut = true;
    pendingEmail = null;
    authCallbackError = false;
    inviteAfterCreate = false;
    ++_generation;
    user = null;
    profile = null;
    activeHousehold = null;
    households = const [];
    restoring = false;
    switching = false;
    passwordRecovery = false;
    scopeRevision++;
    _notify();
    await realtime.switchTo(null);
    if (previous != null) await store.clearUser(previous.id);
    try {
      await auth.logout();
    } on Object {
      errorCode = 'auth';
      _notify();
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    unawaited(realtime.switchTo(null));
    super.dispose();
  }
}
