import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../../inventory/viewmodels/inventory_view_model.dart';
import '../models/household_task.dart';
import '../models/task_comment.dart';
import '../models/task_activity.dart';
import '../repositories/task_repository.dart';
import '../services/task_api_service.dart';

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(this.repository, this.session, this.inventory) {
    _scopeChanged();
    session.addListener(_scopeChanged);
  }
  final TaskRepository repository;
  final SessionViewModel session;
  final InventoryViewModel inventory;
  String? _user, _household;
  int _revision = -1,
      _listRequest = 0,
      _detailRequest = 0,
      _memberRequest = 0,
      _pickerRequest = 0,
      _relatedRequest = 0;
  bool _disposed = false;
  bool listLoading = false,
      detailLoading = false,
      busy = false,
      cached = false,
      listCached = false;
  String? errorCode, relatedError;
  List<HouseholdTask> items = [], related = [];
  HouseholdTask? task;
  List<TaskComment> comments = [];
  List<TaskActivity> activity = [];
  List<TaskAttachment> attachments = [];
  List<Map<String, dynamic>> members = [], candidates = [];
  Map<String, dynamic> summary = {};
  Map<String, String> filters = {};
  final Map<String, int> _pages = {};
  final Map<String, bool> _more = {}, _sectionBusy = {};
  final Map<String, (String, DateTime)> _urls = {};
  int page = 1, total = 0, candidatePage = 1, candidateTotal = 0;
  String? relatedItemId;
  bool relatedLoading = false, relatedCached = false, pickerLoading = false;
  bool get ready =>
      _user != null &&
      _household != null &&
      !session.restoring &&
      !session.switching;
  String get scopeKey => '$_user/$_household/$_revision';
  String? get userId => _user;
  bool get isAdmin => session.activeHousehold?.role == 'admin';
  bool get archived => filters['archived'] == 'true';
  bool more(String section) => _more[section] ?? false;
  bool sectionBusy(String section) => _sectionBusy[section] ?? false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(String scope) => !_disposed && ready && scope == scopeKey;

  void _scopeChanged() {
    final user = session.user?.id, household = session.activeHousehold?.id;
    if (user == _user &&
        household == _household &&
        _revision == session.scopeRevision) {
      return;
    }
    _user = user;
    _household = household;
    _revision = session.scopeRevision;
    _listRequest++;
    _detailRequest++;
    _memberRequest++;
    _pickerRequest++;
    _relatedRequest++;
    items = [];
    task = null;
    comments = [];
    activity = [];
    attachments = [];
    related = [];
    members = [];
    candidates = [];
    summary = {};
    filters = {};
    _pages.clear();
    _more.clear();
    _sectionBusy.clear();
    _urls.clear();
    listLoading = detailLoading = busy = cached = listCached = relatedLoading =
        relatedCached = pickerLoading = false;
    errorCode = relatedError = relatedItemId = null;
    page = 1;
    total = 0;
    candidatePage = 1;
    candidateTotal = 0;
    _notify();
  }

  String _code(Object e) => e is AppException ? e.code : 'unknown';
  void _failure(Object e, {bool householdRead = false}) {
    errorCode = _code(e);
    if (e is UnauthorizedException ||
        e is ForbiddenException ||
        (householdRead && e is NotFoundException)) {
      items = [];
      task = null;
      comments = [];
      activity = [];
      attachments = [];
      _urls.clear();
      if (_user != null && _household != null) {
        unawaited(repository.store.clearHousehold(_user!, _household!));
      }
      unawaited(session.refresh());
    }
  }

  Future<void> load({bool nextPage = false}) async {
    if (!ready || (nextPage && listLoading)) return;
    final scope = scopeKey,
        user = _user!,
        household = _household!,
        request = ++_listRequest;
    final next = nextPage ? page + 1 : 1;
    final query = {
      'as_of': taskToday(),
      ...filters,
      'page': '$next',
      'page_size': '20',
    };
    bool current() => _current(scope) && request == _listRequest;
    listLoading = true;
    errorCode = null;
    if (!nextPage) items = [];
    _notify();
    try {
      final response = await repository.read(
        user,
        household,
        'list.${Uri(queryParameters: {...query}..remove('as_of')).query}',
        () => repository.service.list(household, query),
        current,
      );
      if (!current()) return;
      final loaded = TaskPage(response.data);
      items = nextPage ? [...items, ...loaded.items] : loaded.items;
      page = loaded.page;
      total = loaded.total;
      listCached = response.cached;
      final counts = await repository.read(
        user,
        household,
        'summary',
        () => repository.service.summary(household),
        current,
      );
      if (!current()) return;
      summary = counts.data;
      listCached = listCached || counts.cached;
    } catch (e) {
      if (current()) _failure(e, householdRead: true);
    } finally {
      if (current()) {
        listLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMembers() async {
    if (!ready) return;
    final scope = scopeKey,
        user = _user!,
        household = _household!,
        request = ++_memberRequest;
    bool current() => _current(scope) && request == _memberRequest;
    try {
      final response = await repository.read(
        user,
        household,
        'members',
        () async => {'items': await repository.service.members(household)},
        current,
      );
      if (current()) {
        members = (response.data['items'] as List).cast<Map<String, dynamic>>();
        _notify();
      }
    } catch (e) {
      if (current()) {
        _failure(e);
        _notify();
      }
    }
  }

  Future<void> open(String id) async {
    if (!ready) return;
    final scope = scopeKey,
        user = _user!,
        household = _household!,
        request = ++_detailRequest;
    bool current() => _current(scope) && request == _detailRequest;
    task = null;
    comments = [];
    activity = [];
    attachments = [];
    _urls.clear();
    _pages.clear();
    _more.clear();
    _sectionBusy.clear();
    detailLoading = true;
    cached = false;
    errorCode = null;
    _notify();
    try {
      final response = await repository.read(
        user,
        household,
        'item.$id',
        () => repository.service.detail(household, id),
        current,
      );
      if (!current()) return;
      task = HouseholdTask(response.data);
      cached = response.cached;
      _notify();
      await Future.wait(
        [
          'comments',
          'activity',
          'attachments',
        ].map((section) => loadSection(section)),
      );
    } catch (e) {
      if (current()) _failure(e);
    } finally {
      if (current()) {
        detailLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadSection(String section) async {
    final selected = task;
    if (!ready ||
        selected == null ||
        sectionBusy(section) ||
        (_more[section] == false)) {
      return;
    }
    final scope = scopeKey,
        user = _user!,
        household = _household!,
        request = _detailRequest;
    bool current() => _current(scope) && request == _detailRequest;
    final next = (_pages[section] ?? 0) + 1;
    _sectionBusy[section] = true;
    try {
      final response = await repository.read(
        user,
        household,
        '$section.${selected.id}.$next',
        () => repository.service.section(household, selected.id, section, next),
        current,
      );
      if (!current()) return;
      final rows = (response.data['items'] as List)
          .cast<Map<String, dynamic>>();
      if (rows.any(
        (row) => row['task_id'] != null && row['task_id'] != selected.id,
      )) {
        throw const InvalidResponseException();
      }
      switch (section) {
        case 'comments':
          comments = [...comments, ...rows.map(TaskComment.new)];
        case 'activity':
          activity = [...activity, ...rows.map(TaskActivity.new)];
        case 'attachments':
          attachments = [...attachments, ...rows.map(TaskAttachment.new)];
      }
      _pages[section] = next;
      _more[section] = rows.length == 20;
      cached = cached || response.cached;
    } catch (e) {
      if (current()) _failure(e);
    } finally {
      if (current()) {
        _sectionBusy[section] = false;
        _notify();
      }
    }
  }

  Future<T?> _write<T>(
    Future<T> Function(String) action, {
    HouseholdTask? origin,
  }) async {
    if (!ready ||
        busy ||
        (origin != null && origin.householdId != _household)) {
      return null;
    }
    final scope = scopeKey, user = _user!, household = _household!;
    _listRequest++;
    _detailRequest++;
    _relatedRequest++;
    relatedLoading = false;
    _sectionBusy.clear();
    final detailRequest = _detailRequest;
    listLoading = detailLoading = false;
    busy = true;
    errorCode = null;
    _notify();
    try {
      final result = await action(household);
      if (!_current(scope)) return null;
      if (result is HouseholdTask && result.householdId != household) {
        throw const InvalidResponseException();
      }
      if (result is TaskComment &&
          (result.householdId != household || result.taskId != origin?.id)) {
        throw const InvalidResponseException();
      }
      if (result is TaskAttachment &&
          (result.householdId != household || result.taskId != origin?.id)) {
        throw const InvalidResponseException();
      }
      await repository.invalidate(user, household);
      if (!_current(scope) || detailRequest != _detailRequest) return null;
      if (result is HouseholdTask) task = result;
      cached = false;
      return result;
    } catch (e) {
      if (_current(scope)) _failure(e);
      return null;
    } finally {
      if (_current(scope)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<HouseholdTask?> save(String? id, Map<String, dynamic> fields) =>
      _write(
        (h) async =>
            HouseholdTask(await repository.service.save(h, id, fields)),
      );
  Future<HouseholdTask?> assign(
    HouseholdTask selected,
    String operation,
    String? user,
  ) => _write(
    (h) async => HouseholdTask(
      await repository.service.action(h, selected.id, 'assignment', {
        'expected_revision': selected.revision,
        'operation': operation,
        if (operation == 'assign') 'assigned_to': user,
      }),
    ),
    origin: selected,
  );
  Future<HouseholdTask?> setPriority(
    HouseholdTask selected,
    TaskPriority priority,
  ) => _write(
    (h) async => HouseholdTask(
      await repository.service.action(h, selected.id, 'priority', {
        'expected_revision': selected.revision,
        'priority': priority.name,
      }),
    ),
    origin: selected,
  );
  Future<HouseholdTask?> setStatus(
    HouseholdTask selected,
    TaskStatus status, {
    bool reopen = false,
    String? note,
  }) => _write(
    (h) async => HouseholdTask(
      await repository.service.action(h, selected.id, 'status', {
        'expected_revision': selected.revision,
        'status': statusWire(status),
        'reopen': reopen,
        'completion_note': note,
      }),
    ),
    origin: selected,
  );
  Future<HouseholdTask?> archive(HouseholdTask selected) => _write(
    (h) async => HouseholdTask(
      await repository.service.archive(
        h,
        selected.id,
        selected.revision,
        selected.archived,
      ),
    ),
    origin: selected,
  );

  Future<TaskComment?> addComment(HouseholdTask selected, String body) =>
      _write(
        (h) async => TaskComment(
          await repository.service.comment(
            h,
            selected.id,
            selected.revision,
            body,
          ),
        ),
        origin: selected,
      );
  Future<TaskComment?> editComment(
    HouseholdTask selected,
    TaskComment comment,
    String body,
  ) {
    if (comment.householdId != selected.householdId ||
        comment.taskId != selected.id) {
      return Future.value(null);
    }
    return _write(
      (h) async => TaskComment(
        await repository.service.comment(
          h,
          selected.id,
          selected.revision,
          body,
          commentId: comment.id,
          commentRevision: comment.revision,
        ),
      ),
      origin: selected,
    );
  }

  Future<TaskComment?> deleteComment(
    HouseholdTask selected,
    TaskComment comment,
  ) {
    if (comment.householdId != selected.householdId ||
        comment.taskId != selected.id) {
      return Future.value(null);
    }
    return _write(
      (h) async => TaskComment(
        await repository.service.deleteComment(
          h,
          selected.id,
          selected.revision,
          comment.id,
          comment.revision,
        ),
      ),
      origin: selected,
    );
  }

  Future<TaskAttachment?> upload(
    HouseholdTask selected,
    Uint8List bytes, {
    String? commentId,
  }) => _write(
    (h) async => TaskAttachment(
      await repository.service.upload(
        h,
        selected.id,
        selected.revision,
        bytes,
        commentId,
      ),
    ),
    origin: selected,
  );
  Future<HouseholdTask?> removePhoto(
    HouseholdTask selected,
    TaskAttachment attachment,
  ) {
    if (attachment.householdId != selected.householdId ||
        attachment.taskId != selected.id) {
      return Future.value(null);
    }
    return _write(
      (h) async => HouseholdTask(
        await repository.service.removePhoto(
          h,
          selected.id,
          selected.revision,
          attachment.id,
        ),
      ),
      origin: selected,
    );
  }

  bool canChangeComment(TaskComment comment) =>
      isAdmin || comment.authorId == _user;
  bool canRemovePhoto(TaskAttachment attachment) =>
      isAdmin || attachment.uploaderId == _user;
  String? photoURL(TaskAttachment attachment) {
    if (!ready ||
        attachment.householdId != _household ||
        attachment.taskId != task?.id) {
      return null;
    }
    final value = _urls[attachment.id];
    return value == null || !DateTime.now().isBefore(value.$2)
        ? null
        : value.$1;
  }

  Future<void> signPhoto(TaskAttachment attachment) async {
    final selected = task;
    if (!ready ||
        selected == null ||
        cached ||
        attachment.householdId != _household ||
        attachment.taskId != selected.id) {
      return;
    }
    final scope = scopeKey, request = _detailRequest;
    try {
      final data = await repository.service.photoURL(
        _household!,
        selected.id,
        attachment.id,
      );
      if (_current(scope) && request == _detailRequest) {
        _urls[attachment.id] = (
          data['url'] as String,
          DateTime.now().add(Duration(seconds: data['expires_in'] as int)),
        );
        _notify();
      }
    } catch (e) {
      if (_current(scope) && request == _detailRequest) {
        _failure(e);
        _notify();
      }
    }
  }

  Future<void> searchInventory(String query, {bool nextPage = false}) async {
    if (!ready) return;
    final scope = scopeKey,
        request = ++_pickerRequest,
        next = nextPage ? candidatePage + 1 : 1;
    pickerLoading = true;
    if (!nextPage) candidates = [];
    _notify();
    try {
      final result = await repository.read(
        _user!,
        _household!,
        'inventory.${Uri.encodeComponent(query)}.$next',
        () => repository.service.inventory(_household!, query, next),
        () => _current(scope) && request == _pickerRequest,
      );
      if (!_current(scope) || request != _pickerRequest) return;
      final rows = (result.data['items'] as List).cast<Map<String, dynamic>>();
      candidates = nextPage ? [...candidates, ...rows] : rows;
      candidatePage = next;
      candidateTotal = result.data['total'] as int;
      _notify();
    } catch (e) {
      if (_current(scope) && request == _pickerRequest) {
        candidates = [];
        _failure(e);
        _notify();
      }
    } finally {
      if (_current(scope) && request == _pickerRequest) {
        pickerLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadRelated(String itemId) async {
    if (!ready) return;
    final scope = scopeKey,
        request = ++_relatedRequest,
        h = _household!,
        u = _user!;
    relatedItemId = itemId;
    related = [];
    relatedLoading = true;
    relatedError = null;
    _notify();
    bool current() => _current(scope) && request == _relatedRequest;
    try {
      final response = await repository.read(
        u,
        h,
        'related.$itemId',
        () => repository.service.related(h, itemId),
        current,
      );
      if (current()) {
        related = TaskPage(response.data).items;
        relatedCached = response.cached;
      }
    } catch (e) {
      if (current()) relatedError = _code(e);
    } finally {
      if (current()) {
        relatedLoading = false;
        _notify();
      }
    }
  }

  Future<bool> markLinkedWorking(HouseholdTask completed) async {
    if (!ready ||
        busy ||
        completed.householdId != _household ||
        completed.status != TaskStatus.completed ||
        completed.linkedItemId == null) {
      return false;
    }
    final scope = scopeKey;
    busy = true;
    _notify();
    try {
      await inventory.open(completed.linkedItemId!);
      if (!_current(scope)) return false;
      final selected = inventory.item;
      if (selected == null ||
          selected.id != completed.linkedItemId ||
          selected.householdId != _household ||
          selected.consumable) {
        errorCode = 'inventory_condition_failed';
        return false;
      }
      final result = await inventory.condition(selected, 'working');
      if (!_current(scope)) return false;
      if (result == null) {
        errorCode = 'inventory_condition_failed';
        return false;
      }
      return true;
    } finally {
      if (_current(scope)) {
        busy = false;
        _notify();
      }
    }
  }

  Map<String, dynamic>? draft(String key) => !ready
      ? null
      : repository.store.readDraft(_user!, _household!, 'tasks.$key');
  Future<void> saveDraft(
    String key,
    Map<String, dynamic> value,
    String originScope,
  ) async {
    if (_current(originScope)) {
      await repository.store.saveDraft(
        _user!,
        _household!,
        'tasks.$key',
        value,
      );
    }
  }

  Future<void> clearDraft(String key, String originScope) async {
    if (_current(originScope)) {
      await repository.store.removeDraft(_user!, _household!, 'tasks.$key');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_scopeChanged);
    _urls.clear();
    super.dispose();
  }
}
