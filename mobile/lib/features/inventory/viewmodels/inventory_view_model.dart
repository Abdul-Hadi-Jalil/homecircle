import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(this.repository, this.session) {
    _scopeChanged();
    session.addListener(_scopeChanged);
  }
  final InventoryRepository repository;
  final SessionViewModel session;
  int _revision = -1, _request = 0, _detailRequest = 0;
  bool _disposed = false;
  String? _user, _household;
  bool loading = false, busy = false, cached = false;
  String? error;
  List<InventoryItem> items = [];
  List<Map<String, dynamic>> categories = [], activity = [];
  Map<String, dynamic> summary = {};
  InventoryItem? item;
  Uint8List? photo;
  int total = 0, page = 1, activityPage = 0;
  bool moreActivity = true;
  bool _activityLoading = false;
  Map<String, String> filters = {};
  bool get ready =>
      _user != null &&
      _household != null &&
      !session.switching &&
      !session.restoring;
  bool get archived => filters['archived'] == 'true';
  String get draftKey => 'inventory.${item?.id ?? 'new'}';

  void _scopeChanged() {
    final user = session.user?.id, household = session.activeHousehold?.id;
    if (_revision == session.scopeRevision &&
        user == _user &&
        household == _household) {
      return;
    }
    _revision = session.scopeRevision;
    _user = user;
    _household = household;
    _request++;
    _detailRequest++;
    items = [];
    categories = [];
    activity = [];
    summary = {};
    item = null;
    photo = null;
    error = null;
    total = 0;
    page = 1;
    loading = busy = cached = false;
    filters = {};
    _activityLoading = false;
    _notify();
  }

  bool _current(int revision, String user, String household) =>
      !_disposed &&
      ready &&
      revision == _revision &&
      user == _user &&
      household == _household;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _accessFailure(
    Object error,
    String user,
    String household, {
    bool householdRead = false,
  }) {
    if (error is UnauthorizedException ||
        error is ForbiddenException ||
        (householdRead && error is NotFoundException)) {
      items = [];
      item = null;
      photo = null;
      activity = [];
      summary = {};
      unawaited(repository.store.clearHousehold(user, household));
      unawaited(session.refresh());
    }
  }

  String message(Object e) => e is AppException
      ? switch (e.code) {
          'revision_conflict' => 'This item changed. Refresh to review the latest version before saving again.',
          'network' => 'You are offline. Saved inventory and form drafts remain available.',
          'invalid_photo' =>
            'Choose a JPEG, PNG or WebP up to 5 MiB and 16 MP.',
          'not_found' ||
          'forbidden' => 'This item or household is no longer available.',
          'duplicate_category' => 'That category already exists.',
          _ => 'Could not save or load inventory. Check your connection and try again.',
        }
      : 'Could not load inventory. Please try again.';

  Future<void> load({bool more = false}) async {
    if (!ready || (more && loading)) return;
    final user = _user!, household = _household!, revision = _revision;
    final request = ++_request, next = more ? page + 1 : 1;
    final query = {...filters, 'page': '$next', 'page_size': '20'};
    bool current() =>
        _current(revision, user, household) && request == _request;
    loading = true;
    error = null;
    if (!more) items = [];
    _notify();
    try {
      final result = await repository.read(
        user,
        household,
        'list.${Uri(queryParameters: query).query}',
        () => repository.service.list(household, query),
        current,
      );
      if (!current()) return;
      final data = InventoryPage.fromJson(result.value);
      items = more ? [...items, ...data.items] : data.items;
      total = data.total;
      page = data.page;
      cached = result.cached;
      final metadata = await repository.read(
        user,
        household,
        'metadata',
        () async => {
          'categories': await repository.service.categories(household),
          'summary': await repository.service.summary(household),
        },
        current,
      );
      if (!current()) return;
      categories = (metadata.value['categories'] as List)
          .cast<Map<String, dynamic>>();
      summary = metadata.value['summary'] as Map<String, dynamic>;
      cached = cached || metadata.cached;
    } catch (e) {
      if (current()) {
        error = message(e);
        _accessFailure(e, user, household, householdRead: true);
      }
    } finally {
      if (current()) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> open(String id) async {
    if (!ready) return;
    final user = _user!, household = _household!, revision = _revision;
    final request = ++_detailRequest;
    bool current() =>
        _current(revision, user, household) && request == _detailRequest;
    loading = true;
    error = null;
    item = null;
    photo = null;
    cached = false;
    activity = [];
    activityPage = 0;
    moreActivity = true;
    _activityLoading = false;
    _notify();
    try {
      final result = await repository.read(
        user,
        household,
        'item.$id',
        () => repository.service.detail(household, id),
        current,
      );
      if (!current()) return;
      final loaded = InventoryItem(result.value);
      if (loaded.householdId != household) {
        throw const InvalidResponseException();
      }
      item = loaded;
      cached = result.cached;
      _notify();
      await loadActivity();
      if (!current()) return;
      if (loaded.photoPath != null && !loaded.archived && !cached) {
        try {
          final data = await repository.service.api.get(
            repository.service.path(household, '/$id/photo'),
          ) as Map<String, dynamic>;
          if (current()) photo = base64Decode(data['data_base64'] as String);
        } catch (_) {
          if (current()) {
            error = 'The photo could not be loaded. Refresh to try again.';
          }
        }
      }
    } catch (e) {
      if (current()) {
        error = message(e);
        _accessFailure(e, user, household);
      }
    } finally {
      if (current()) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadActivity() async {
    final selected = item;
    if (!ready || selected == null || !moreActivity || _activityLoading) return;
    _activityLoading = true;
    final user = _user!, household = _household!, revision = _revision;
    final request = _detailRequest, next = activityPage + 1;
    bool current() =>
        _current(revision, user, household) && request == _detailRequest;
    try {
      final data = await repository.read(
        user,
        household,
        'activity.${selected.id}.$next',
        () => repository.service.activity(household, selected.id, next),
        current,
      );
      if (!current()) return;
      final batch = (data.value['items'] as List).cast<Map<String, dynamic>>();
      activity = [...activity, ...batch];
      activityPage = next;
      moreActivity = batch.length == 20;
      cached = cached || data.cached;
      _notify();
    } catch (e) {
      if (current()) {
        error = message(e);
        _notify();
      }
    } finally {
      if (current()) _activityLoading = false;
    }
  }

  Future<InventoryItem?> mutate(
    Future<Map<String, dynamic>> Function(String) action,
  ) async {
    if (!ready || busy) return null;
    final user = _user!, household = _household!, revision = _revision;
    bool current() => _current(revision, user, household);
    // A response started before this write must not reintroduce stale snapshots.
    _request++;
    _detailRequest++;
    loading = false;
    _activityLoading = false;
    busy = true;
    error = null;
    _notify();
    try {
      final result = InventoryItem(await action(household));
      if (!current()) return null;
      if (result.householdId != household) {
        throw const InvalidResponseException();
      }
      await repository.invalidate(user, household);
      if (!current()) return null;
      item = result;
      cached = false;
      return result;
    } catch (e) {
      if (current()) {
        error = message(e);
        _accessFailure(e, user, household);
      }
      return null;
    } finally {
      if (current()) {
        busy = false;
        _notify();
      }
    }
  }

  Future<InventoryItem?> save(String? id, Map<String, dynamic> fields) =>
      mutate((h) => repository.service.save(h, id, fields));

  Future<InventoryItem?> _forItem(
    InventoryItem selected,
    Future<Map<String, dynamic>> Function(String) action,
  ) {
    if (!ready || selected.householdId != _household) return Future.value(null);
    return mutate(action);
  }

  Future<InventoryItem?> quantity(
    InventoryItem selected,
    String operation,
    String amount,
  ) => _forItem(
    selected,
    (h) async => await repository.service.api.patch(
      repository.service.path(h, '/${selected.id}/quantity'),
      body: {
        'operation': operation,
        'amount': amount,
        if (operation == 'set') 'expected_revision': selected.revision,
      },
    ) as Map<String, dynamic>,
  );
  Future<InventoryItem?> condition(InventoryItem selected, String value) =>
      _forItem(
        selected,
        (h) async => await repository.service.api.patch(
          repository.service.path(h, '/${selected.id}/condition'),
          body: {'condition': value, 'expected_revision': selected.revision},
        ) as Map<String, dynamic>,
      );
  Future<InventoryItem?> archive(InventoryItem selected) => _forItem(
    selected,
    (h) async => selected.archived
        ? await repository.service.api.post(
            repository.service.path(h, '/${selected.id}/restore'),
            body: {'expected_revision': selected.revision},
          ) as Map<String, dynamic>
        : await repository.service.api.delete(
            '${repository.service.path(h, '/${selected.id}')}?expected_revision=${selected.revision}',
          ) as Map<String, dynamic>,
  );
  Future<InventoryItem?> upload(InventoryItem selected, Uint8List bytes) =>
      _forItem(
        selected,
        (h) async => await repository.service.api.put(
          repository.service.path(h, '/${selected.id}/photo'),
          body: {
            'expected_revision': selected.revision,
            'data_base64': base64Encode(bytes),
          },
        ) as Map<String, dynamic>,
      );
  Future<InventoryItem?> removePhoto(InventoryItem selected) => _forItem(
    selected,
    (h) async => await repository.service.api.delete(
      '${repository.service.path(h, '/${selected.id}/photo')}?expected_revision=${selected.revision}',
    ) as Map<String, dynamic>,
  );

  Map<String, dynamic>? draft(String key) => !ready
      ? null
      : repository.store.readDraft(_user!, _household!, 'inventory.$key');
  Future<void> saveDraft(String key, Map<String, dynamic> value) async {
    if (ready) {
      await repository.store.saveDraft(
        _user!,
        _household!,
        'inventory.$key',
        value,
      );
    }
  }

  Future<void> clearDraft(String key) async {
    if (ready) {
      await repository.store.removeDraft(_user!, _household!, 'inventory.$key');
    }
  }

  Future<bool> addCategory(String name) async {
    if (!ready || busy) return false;
    final revision = _revision, user = _user!, household = _household!;
    busy = true;
    error = null;
    _notify();
    try {
      await repository.service.api.post(
        repository.service.path(household, '/categories'),
        body: {'name': name},
      );
      if (!_current(revision, user, household)) return false;
      await load();
      return true;
    } catch (e) {
      if (_current(revision, user, household)) error = message(e);
      return false;
    } finally {
      if (_current(revision, user, household)) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_scopeChanged);
    super.dispose();
  }
}
