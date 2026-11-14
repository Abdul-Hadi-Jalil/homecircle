import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../chat/models/chat_message.dart';
import '../../dashboard/models/household_hub.dart';
import '../../dashboard/viewmodels/scoped_hub_model.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../services/push_service.dart';

class NotificationsViewModel extends ScopedHubModel {
  NotificationsViewModel(super.repository, super.session, this.push) {
    subscriptions.add(
      push.foreground.listen((value) {
        if (ready) {
          foregroundId = value['notification_id'] is String
              ? value['notification_id'] as String
              : null;
          banner = true;
          emit();
          invalidate();
        }
      }),
    );
    subscriptions.add(push.opened.listen(acceptPush));
    tokenSubscription = push.tokenChanges.listen((value) {
      if (ready) unawaited(registerToken(value));
    });
    session.addListener(checkSession);
    session.beforeLogout = unregisterForLogout;
    unawaited(
      push
          .initial()
          .then((data) {
            if (data != null) acceptPush(data);
          })
          .catchError((_) {}),
    );
    checkSession();
  }
  final PushService push;
  final List<StreamSubscription<Map<String, dynamic>>> subscriptions = [];
  StreamSubscription<String>? tokenSubscription;
  Timer? debounce;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> preferences = {};
  int unread = 0;
  bool more = false,
      unreadOnly = false,
      banner = false,
      preferencesBusy = false,
      resolving = false;
  bool preferencesCached = false;
  String? cursor, pendingId, pendingUser;
  HubDestination? destination;
  PushPermission permission = PushPermission.unavailable;
  String? registeredUser;
  String? foregroundId;
  void Function()? changed;
  @override
  void reset() {
    items = [];
    unread = 0;
    cursor = null;
    more = false;
    unreadOnly = false;
    preferences = {};
    banner = false;
    foregroundId = null;
    destination = null;
    preferencesCached = false;
  }

  void checkSession() {
    if (disposed) return;
    if (pendingUser != null && session.user?.id != pendingUser) {
      pendingId = pendingUser = null;
      destination = null;
    }
    if (ready && registeredUser != user) {
      registeredUser = user;
      unawaited(preparePush());
    }
    if (ready && pendingId != null && !resolving) unawaited(resolvePending());
    // A validated multi-household session may have no selected household yet.
    if (session.user != null &&
        !session.restoring &&
        !session.switching &&
        !session.passwordRecovery &&
        pendingId != null &&
        !resolving) {
      unawaited(resolvePending());
    }
    if (session.user == null) registeredUser = null;
  }

  void invalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (ready) {
        unawaited(load());
        changed?.call();
      }
    });
  }

  Future<String> installation() async {
    final actor = user;
    final stored = await repository.cache.read(actor, 'device', 'installation');
    if (stored?['id'] is String) return stored!['id'] as String;
    final id = chatUuid();
    await repository.cache.write(actor, 'device', 'installation', {'id': id});
    return id;
  }

  Future<void> preparePush() async {
    final captured = scope;
    try {
      final value = await push.permission();
      if (!current(captured)) return;
      permission = value;
      emit();
      if (value == PushPermission.authorized) {
        final token = await push.token();
        if (token != null && current(captured)) await registerToken(token);
      }
    } catch (_) {
      if (current(captured)) {
        error = 'push_registration';
        emit();
      }
    }
  }

  Future<void> requestPermission() async {
    if (!ready) return;
    final captured = scope;
    try {
      final asked =
          session.store.preferences.getBool(
            'homecircle.push.permissionAsked',
          ) ??
          false;
      final existing = await push.permission();
      if (!current(captured)) return;
      if (existing == PushPermission.denied && asked) {
        permission = existing;
        emit();
        return;
      }
      await session.store.preferences.setBool(
        'homecircle.push.permissionAsked',
        true,
      );
      final status = await push.permission(request: true);
      if (!current(captured)) return;
      permission = status;
      emit();
      if (status == PushPermission.authorized) {
        final value = await push.token();
        if (value != null && current(captured)) await registerToken(value);
      }
    } catch (_) {
      if (current(captured)) {
        error = 'push_registration';
        emit();
      }
    }
  }

  Future<void> registerToken(String token) async {
    if (!ready) return;
    final captured = scope;
    try {
      final id = await installation();
      if (current(captured)) await repository.service.register(token, id);
    } catch (_) {
      if (current(captured)) {
        error = 'push_registration';
        emit();
      }
    }
  }

  Future<void> unregisterForLogout() async {
    // Invoked while the verified Auth session can still revoke this installation.
    final actor = user;
    final removing = push.removeToken().catchError((_) {});
    try {
      final stored = await repository.cache.read(
        actor,
        'device',
        'installation',
      );
      if (stored?['id'] is String) {
        await repository.service.revoke(stored!['id'] as String);
      }
    } catch (_) {}
    await removing;
  }

  void validate(Map<String, dynamic> data, String h, String u) {
    for (final row in data['items'] as List) {
      if (row['household_id'] != h || row['recipient_user_id'] != u) {
        throw const InvalidResponseException();
      }
    }
  }

  @override
  Future<void> load() => page();
  Future<void> filter(bool unread) async {
    request++;
    loading = false;
    unreadOnly = unread;
    items = [];
    cursor = null;
    await load();
  }

  Future<void> page({bool next = false}) async {
    if (!ready || loading || (next && !more)) return;
    final captured = scope, number = ++request, u = user, h = home;
    loading = true;
    error = null;
    emit();
    final key = 'notifications.$unreadOnly',
        query = <String, String>{
          'unread_only': '$unreadOnly',
          'page_size': '30',
          if (next && cursor != null) 'cursor': cursor!,
        };
    try {
      final result = await repository.read(
        u,
        h,
        next ? '$key.$cursor' : key,
        () async {
          final data = await repository.service.notifications(h, query);
          data['unread_count'] = (await repository.service.count(h))['count'];
          return data;
        },
        () => current(captured) && number == request,
        (data) => validate(data, h, u),
      );
      if (!current(captured) || number != request) return;
      final rows = (result.data['items'] as List).cast<Map<String, dynamic>>();
      items = {
        for (final row in [
          ...(next ? items : <Map<String, dynamic>>[]),
          ...rows,
        ])
          row['id']: row,
      }.values.toList();
      cursor = result.data['cursor'] as String?;
      more = result.data['has_more'] == true;
      adopt(result);
      unread = result.data['unread_count'] as int;
    } catch (e) {
      if (current(captured) && number == request) failed(e);
    } finally {
      if (current(captured) && number == request) {
        loading = false;
        emit();
      }
    }
  }

  Future<bool> action(String? id, String action) async {
    if (!ready || busy) return false;
    final captured = scope, h = home;
    busy = true;
    error = null;
    emit();
    try {
      if (id == null) {
        await repository.service.markAll(h);
      } else {
        await repository.service.mark(id, action);
      }
      if (!current(captured)) return false;
      // Never optimistically synchronize a read/dismiss action while offline.
      await load();
      changed?.call();
      return true;
    } catch (e) {
      if (current(captured)) failed(e);
      return false;
    } finally {
      if (current(captured)) {
        busy = false;
        emit();
      }
    }
  }

  Future<void> loadPreferences() async {
    if (!ready || preferencesBusy) return;
    final captured = scope, u = user, h = home;
    preferencesBusy = true;
    error = null;
    emit();
    try {
      final result = await repository.read(
        u,
        h,
        'preferences',
        () => repository.service.preferences(h),
        () => current(captured),
        (data) {
          if (data['user_id'] != u || data['household_id'] != h) {
            throw const InvalidResponseException();
          }
        },
      );
      if (current(captured)) {
        preferences = result.data;
        preferencesCached = result.cached;
        cacheError = result.cacheError;
      }
    } catch (e) {
      if (current(captured)) failed(e);
    } finally {
      if (current(captured)) {
        preferencesBusy = false;
        emit();
      }
    }
    await preparePush();
  }

  Future<bool> setPreference(String key, bool value) async {
    if (!ready || preferencesBusy) return false;
    final captured = scope, h = home, u = user;
    preferencesBusy = true;
    error = null;
    emit();
    try {
      final data = await repository.service.updatePreferences(h, {key: value});
      if (!current(captured)) return false;
      if (data['user_id'] != u || data['household_id'] != h) {
        throw const InvalidResponseException();
      }
      preferences = data;
      preferencesCached = false;
      try {
        await repository.cache.write(u, h, 'hub.preferences', {
          'data': data,
          'saved_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        cacheError = true;
      }
      return true;
    } catch (e) {
      if (current(captured)) failed(e);
      return false;
    } finally {
      if (current(captured)) {
        preferencesBusy = false;
        emit();
      }
    }
  }

  void acceptPush(Map<String, dynamic> data) {
    final id = data['notification_id'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      return;
    }
    pendingId = id;
    pendingUser = session.user?.id;
    checkSession();
  }

  Future<void> resolvePending() async {
    if (resolving || pendingId == null || session.user == null) return;
    resolving = true;
    final id = pendingId!, actor = session.user!.id;
    pendingId = null;
    try {
      final record = await repository.service.notification(id);
      if (disposed || session.user?.id != actor) return;
      if (record['recipient_user_id'] != actor ||
          record['dismissed_at'] != null) {
        throw const NotFoundException();
      }
      final h = record['household_id'] as String;
      // API lookup proves recipient membership; household selection revalidates it.
      if (session.activeHousehold?.id != h) {
        await session.selectHousehold(h);
      }
      if (disposed ||
          session.user?.id != actor ||
          session.activeHousehold?.id != h ||
          session.stage != ApplicationStage.householdReady) {
        throw const ForbiddenException();
      }
      final target = await resolveEntity(
        record['related_entity_type'] as String,
        record['related_entity_id'] as String,
        h,
      );
      if (target != null && session.user?.id == actor) {
        await repository.service.mark(id, 'read');
        if (!disposed &&
            session.user?.id == actor &&
            session.activeHousehold?.id == h) {
          destination = target;
          emit();
          unawaited(load());
        }
      }
    } catch (e) {
      if (!disposed && session.user?.id == actor) {
        error = e is AppException ? e.code : 'unknown';
        emit();
      }
    } finally {
      resolving = false;
      pendingUser = null;
      if (pendingId != null) checkSession();
    }
  }

  Future<HubDestination?> resolveEntity(
    String type,
    String id,
    String household,
  ) async {
    if (!ready || home != household) return null;
    final captured = scope;
    try {
      final suffix = switch (type) {
        'task' => 'tasks/$id',
        'shopping' => 'shopping/$id',
        'inventory' => 'inventory/$id',
        'chat' => 'chat/messages/$id',
        'household' => 'activity',
        _ => throw const InvalidResponseException(),
      };
      final record = await repository.service.get(
        repository.service.household(household, suffix),
      );
      if (!current(captured)) return null;
      if (type != 'household' &&
          (record['household_id'] != household ||
              record['id'] != id ||
              record['deleted_at'] != null)) {
        throw const NotFoundException();
      }
      return switch (type) {
        'task' => HubDestination('taskDetails', id: id),
        'shopping' => HubDestination('shoppingDetails', id: id),
        'inventory' => HubDestination('inventoryDetails', id: id),
        'chat' => const HubDestination('chat'),
        _ => const HubDestination('familyActivity'),
      };
    } catch (e) {
      if (current(captured)) {
        error = e is AppException ? e.code : 'unknown';
        emit();
      }
      return null;
    }
  }

  HubDestination? takeDestination() {
    final value = destination;
    destination = null;
    return value;
  }

  @override
  void dispose() {
    session.removeListener(checkSession);
    session.beforeLogout = null;
    debounce?.cancel();
    for (final sub in subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(tokenSubscription?.cancel());
    unawaited(push.dispose());
    super.dispose();
  }
}
