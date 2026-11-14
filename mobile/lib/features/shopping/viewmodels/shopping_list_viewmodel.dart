import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../../inventory/viewmodels/inventory_view_model.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../models/shopping_item.dart';
import '../models/shopping_summary.dart';
import '../repositories/shopping_repository.dart';

class ShoppingListViewModel extends ChangeNotifier {
  ShoppingListViewModel(
    this.repository,
    this.session,
    this.tasks,
    this.inventory,
  ) {
    scopeChanged();
    session.addListener(scopeChanged);
  }
  final ShoppingRepository repository;
  final SessionViewModel session;
  final TasksViewModel tasks;
  final InventoryViewModel inventory;
  String scope = '';
  String? user, household, error;
  bool disposed = false,
      loading = false,
      busy = false,
      cached = false,
      detailCached = false;
  int generation = 0,
      historyGeneration = 0,
      detailGeneration = 0,
      page = 1,
      total = 0,
      historyPage = 1;
  List<ShoppingItem> items = [];
  ShoppingItem? selected;
  ShoppingSummary summary = const ShoppingSummary({});
  List<Map<String, dynamic>> history = [];
  bool moreHistory = false, historyCached = false, historyLoading = false;
  Map<String, String> filters = {};
  bool get ready =>
      !disposed &&
      session.stage == ApplicationStage.householdReady &&
      household != null &&
      user != null;
  bool current(String captured) => ready && scope == captured;
  void emit() {
    if (!disposed) notifyListeners();
  }

  void scopeChanged() {
    final next =
        '${session.user?.id}:${session.activeHousehold?.id}:${session.scopeRevision}';
    if (next == scope) return;
    scope = next;
    user = session.user?.id;
    household = session.activeHousehold?.id;
    generation++;
    historyGeneration++;
    detailGeneration++;
    items = [];
    selected = null;
    history = [];
    summary = const ShoppingSummary({});
    filters = {};
    busy = loading = cached = detailCached = historyCached = historyLoading =
        moreHistory = false;
    error = null;
    page = historyPage = 1;
    total = 0;
    emit();
  }

  void failure(Object e, {bool householdRead = false}) {
    error = e is AppException ? e.code : 'unknown';
    if (e is UnauthorizedException ||
        e is ForbiddenException ||
        (householdRead && e is NotFoundException)) {
      items = [];
      selected = null;
      history = [];
      summary = const ShoppingSummary({});
      if (user != null && household != null) {
        unawaited(repository.store.clearHousehold(user!, household!));
      }
      unawaited(session.refresh());
    }
  }

  Future<void> load({bool nextPage = false}) async {
    if (!ready || (nextPage && loading)) return;
    final captured = scope, h = household!, u = user!, request = ++generation;
    final next = nextPage ? page + 1 : 1;
    final query = {...filters, 'page': '$next', 'page_size': '20'};
    bool valid() => current(captured) && generation == request;
    loading = true;
    error = null;
    if (!nextPage) items = [];
    emit();
    try {
      final read = await repository.read(
        u,
        h,
        'list.${Uri(queryParameters: query).query}',
        () => repository.shopping.list(h, query),
        valid,
      );
      if (!valid()) return;
      final rows = (read.data['items'] as List)
          .map((e) => ShoppingItem(e as Map<String, dynamic>))
          .toList();
      items = nextPage ? [...items, ...rows] : rows;
      total = read.data['total'] as int;
      page = next;
      cached = read.cached;
      final counts = await repository.read(
        u,
        h,
        'summary.${Uri(queryParameters: filters).query}',
        () => repository.shopping.list(h, filters, suffix: '/summary'),
        valid,
      );
      if (!valid()) return;
      summary = ShoppingSummary(counts.data);
      cached = cached || counts.cached;
    } catch (e) {
      if (valid()) failure(e, householdRead: true);
    } finally {
      if (valid()) {
        loading = false;
        emit();
      }
    }
  }

  Future<ShoppingItem?> open(String id) async {
    if (!ready) return null;
    final captured = scope,
        h = household!,
        u = user!,
        request = ++detailGeneration;
    bool valid() => current(captured) && detailGeneration == request;
    selected = null;
    error = null;
    emit();
    try {
      final read = await repository.read(
        u,
        h,
        'item.$id',
        () => repository.shopping.detail(h, id),
        valid,
      );
      if (!valid()) return null;
      final row = ShoppingItem(read.data);
      if (row.id != id || row.householdId != h) {
        throw const InvalidResponseException();
      }
      detailCached = read.cached;
      selected = row;
      emit();
      return row;
    } catch (e) {
      if (valid()) {
        failure(e);
        emit();
      }
      return null;
    }
  }

  Future<T?> write<T>(
    Future<T> Function(String h) operation, {
    ShoppingItem? origin,
    required String originScope,
  }) async {
    if (!current(originScope) ||
        busy ||
        (origin != null && origin.householdId != household)) {
      return null;
    }
    final h = household!, u = user!;
    generation++;
    historyGeneration++;
    historyLoading = false;
    history = [];
    detailGeneration++;
    busy = true;
    loading = false;
    error = null;
    emit();
    try {
      final result = await operation(h);
      if (result is ShoppingItem && result.householdId != h) {
        throw const InvalidResponseException();
      }
      await repository.invalidate(u, h);
      await tasks.repository.invalidate(u, h);
      if (!current(originScope)) return null;
      if (result is ShoppingItem) selected = result;
      await load();
      return current(originScope) ? result : null;
    } catch (e) {
      if (current(originScope)) {
        failure(e);
        if (error == 'revision_conflict' ||
            error == 'already_claimed' ||
            error == 'purchase_changed') {
          final code = error;
          await load();
          if (origin != null && current(originScope)) await open(origin.id);
          error = code;
        }
      }
      return null;
    } finally {
      if (current(originScope)) {
        busy = false;
        emit();
      }
    }
  }

  Future<ShoppingItem?> save(
    String? id,
    Map<String, dynamic> fields,
    String originalScope,
  ) => write((h) async {
    final result = ShoppingItem(await repository.shopping.save(h, id, fields));
    if (id != null && result.id != id) throw const InvalidResponseException();
    return result;
  }, originScope: originalScope);
  Future<ShoppingItem?> action(
    ShoppingItem item,
    String action, {
    Map<String, dynamic> fields = const {},
  }) => write(
    (h) async {
      final result = ShoppingItem(
        await repository.shopping.action(h, item.id, action, {
          ...fields,
          'expected_revision': item.revision,
        }),
      );
      if (result.id != item.id) throw const InvalidResponseException();
      return result;
    },
    origin: item,
    originScope: scope,
  );
  Future<bool> apply(ShoppingItem item) async {
    final captured = scope, h = household, u = user;
    final result = await write(
      (home) async {
        final data = await repository.shopping.action(
          home,
          item.id,
          'apply-inventory',
          {'expected_revision': item.revision, 'purchase_id': item.purchaseId},
        );
        if (data['applied'] != true || data['purchase_id'] != item.purchaseId) {
          throw const InvalidResponseException();
        }
        await inventory.repository.invalidate(u!, h!);
        return true;
      },
      origin: item,
      originScope: captured,
    );
    if (result == true && current(captured)) {
      await open(item.id);
      await inventory.load();
      if (current(captured) && inventory.item?.id == item.linkedItemId) {
        await inventory.open(item.linkedItemId!);
      }
    }
    return result == true;
  }

  Future<void> loadHistory({bool nextPage = false}) async {
    if (!ready || historyLoading) return;
    final captured = scope,
        request = ++historyGeneration,
        next = nextPage ? historyPage + 1 : 1;
    bool valid() => current(captured) && request == historyGeneration;
    historyLoading = true;
    error = null;
    emit();
    try {
      final query = {...filters, 'page': '$next', 'page_size': '20'};
      final read = await repository.read(
        user!,
        household!,
        'history.${Uri(queryParameters: query).query}',
        () => repository.shopping.list(household!, query, suffix: '/history'),
        valid,
      );
      if (!valid()) return;
      final rows = (read.data['items'] as List).cast<Map<String, dynamic>>();
      history = nextPage ? [...history, ...rows] : rows;
      historyPage = next;
      moreHistory = rows.length == 20;
      historyCached = read.cached;
    } catch (e) {
      if (valid()) failure(e);
    } finally {
      if (valid()) {
        historyLoading = false;
        emit();
      }
    }
  }

  Map<String, dynamic>? draft(String key) => ready
      ? repository.store.readDraft(user!, household!, 'shopping.$key')
      : null;
  Future<void> saveDraft(
    String key,
    Map<String, dynamic> data,
    String captured,
  ) async {
    if (current(captured)) {
      await repository.store.saveDraft(
        user!,
        household!,
        'shopping.$key',
        data,
      );
    }
  }

  Future<void> clearDraft(String key, String captured) async {
    if (current(captured)) {
      await repository.store.removeDraft(user!, household!, 'shopping.$key');
    }
  }

  Future<List<ShoppingItem>> duplicates(String itemId) async {
    if (!ready) return [];
    final captured = scope;
    final data = await repository.shopping.list(household!, {
      'linked_inventory_item_id': itemId,
      'view': 'active',
      'page_size': '5',
    });
    if (!current(captured)) return [];
    final rows = (data['items'] as List)
        .map((e) => ShoppingItem(e as Map<String, dynamic>))
        .toList();
    if (rows.any((e) => e.householdId != household)) {
      throw const InvalidResponseException();
    }
    return rows;
  }

  @override
  void dispose() {
    disposed = true;
    session.removeListener(scopeChanged);
    super.dispose();
  }
}
