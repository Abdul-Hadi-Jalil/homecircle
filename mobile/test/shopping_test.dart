import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/features/shopping/models/shopping_item.dart';
import 'package:homecircle/features/shopping/models/shopping_summary.dart';
import 'package:homecircle/features/shopping/viewmodels/shopping_form_viewmodel.dart';
import 'package:homecircle/features/tasks/models/household_task.dart';

import 'support/fakes.dart';
import 'tasks_test.dart'
    show
        TaskServer,
        taskRow,
        response,
        fixture,
        tapVisible,
        startTasks,
        captureTask;

Map<String, dynamic> shoppingRow({String home = 'a', String id = 'oil'}) => {
  ...taskRow(home: home, id: id, type: 'shopping', title: 'Cooking Oil'),
  'quantity': '5',
  'unit': 'L',
  'linked_inventory_item_id': 'tap',
  'linked_inventory_name': 'Cooking Oil',
  'linked_inventory_type': 'consumable',
  'purchase_id': null,
  'actual_quantity': null,
  'purchased_by': null,
  'purchased_at': null,
  'purchase_price': null,
  'currency_code': null,
  'inventory_updated_at': null,
};

class ShoppingServer extends TaskServer {
  ShoppingServer() {
    shopping['oil'] = shoppingRow();
  }
  final shopping = <String, Map<String, dynamic>>{};
  final purchases = <Map<String, dynamic>>[];
  final applied = <String>{};
  double stock = .5;
  int purchaseCount = 0;
  bool badHousehold = false;
  Future<http.Response> Function(http.Request)? overrideShopping;
  @override
  Future<http.Response> call(http.Request request) async {
    if (!request.url.path.contains('/shopping')) return super.call(request);
    requests.add(request);
    if (offline) throw http.ClientException('Offline');
    if (overrideShopping != null) return overrideShopping!(request);
    final segments = request.url.pathSegments,
        home = segments[3],
        query = request.url.queryParameters;
    if (segments.length == 5 && request.method == 'GET') {
      var items = shopping.values
          .where((e) => e['household_id'] == home)
          .toList();
      if (query['linked_inventory_item_id'] != null) {
        items = items
            .where(
              (e) =>
                  e['linked_inventory_item_id'] ==
                  query['linked_inventory_item_id'],
            )
            .toList();
      }
      if (query['view'] == 'active') {
        items = items
            .where(
              (e) => e['status'] != 'completed' && e['status'] != 'cancelled',
            )
            .toList();
      }
      if (query['view'] == 'purchased') {
        items = items.where((e) => e['status'] == 'completed').toList();
      }
      if (query['search']?.isNotEmpty == true) {
        items = items
            .where(
              (e) => (e['title'] as String).toLowerCase().contains(
                query['search']!.toLowerCase(),
              ),
            )
            .toList();
      }
      return response({
        'items': items
            .map((e) => {...e, if (badHousehold) 'household_id': 'foreign'})
            .toList(),
        'total': items.length,
        'page': 1,
      });
    }
    if (segments.last == 'summary') {
      final rows = shopping.values
          .where((e) => e['household_id'] == home && e['status'] != 'cancelled')
          .toList();
      final count = rows.where((e) => e['status'] == 'completed').length;
      return response({
        'active': rows.length - count,
        'purchased': count,
        'total': rows.length,
        'high_priority': 0,
        'assigned_to_me': 0,
      });
    }
    if (segments.last == 'history') {
      return response({
        'items': purchases.where((e) => e['household_id'] == home).toList(),
        'page': 1,
      });
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (segments.length == 5 && request.method == 'POST') {
      final id = 'new-${shopping.length}';
      final row = shoppingRow(home: home, id: id)
        ..addAll(body)
        ..['priority'] = body['priority'] ?? 'normal';
      shopping[id] = row;
      return response(row, 201);
    }
    final row = shopping[segments[5]];
    if (row == null || row['household_id'] != home) {
      return response({
        'error': {'code': 'not_found'},
      }, 404);
    }
    if (request.method == 'GET') return response(row);
    final action = segments.last;
    if (action == 'apply-inventory' && applied.contains(body['purchase_id'])) {
      return response({
        'applied': true,
        'already_applied': true,
        'purchase_id': body['purchase_id'],
      });
    }
    if (body['expected_revision'] != row['revision']) {
      return response({
        'error': {'code': 'revision_conflict'},
      }, 409);
    }
    if (action == 'claim' || action == 'assignment') {
      row['assigned_to'] = action == 'claim' ? 'user-a' : body['assigned_to'];
      row['assignee_name'] = row['assigned_to'] == null ? null : 'Arham';
    } else if (action == 'purchase') {
      row.addAll({
        'status': 'completed',
        'purchase_id': 'purchase-${++purchaseCount}',
        'actual_quantity': body['actual_quantity'] ?? row['quantity'],
        'purchased_by': 'user-a',
        'purchaser_name': 'Arham',
        'purchased_at': '2026-11-14T10:00:00Z',
        'completed_at': '2026-11-14T10:00:00Z',
        'purchase_price': body['purchase_price'],
        'currency_code': body['currency_code'],
      });
      purchases.add({
        'id': 'history-$purchaseCount',
        'task_id': row['id'],
        'household_id': home,
        'title': row['title'],
        'actor_name': 'Arham',
        'created_at': row['purchased_at'],
        'purchase': {
          'quantity': row['actual_quantity'],
          'unit': row['unit'],
          'title': row['title'],
          'purchase_price': row['purchase_price'],
          'currency_code': row['currency_code'],
        },
      });
    } else if (action == 'undo-purchase') {
      row['status'] = 'open';
      for (final key in [
        'purchase_id',
        'actual_quantity',
        'purchased_by',
        'purchased_at',
        'purchase_price',
        'currency_code',
        'inventory_updated_at',
        'completed_at',
      ]) {
        row[key] = null;
      }
    } else if (action == 'cancel') {
      row['status'] = 'cancelled';
    } else if (action == 'apply-inventory') {
      if (failInventory) {
        return response({
          'error': {'code': 'inventory_not_ready'},
        }, 422);
      }
      applied.add(row['purchase_id'] as String);
      stock += double.parse(row['actual_quantity'] as String);
      row['inventory_updated_at'] = '2026-11-14T10:01:00Z';
    } else {
      row.addAll(body..remove('expected_revision'));
    }
    row['revision'] = (row['revision'] as int) + 1;
    if (action == 'apply-inventory') {
      return response({'applied': true, 'purchase_id': row['purchase_id']});
    }
    return response(row);
  }
}

Future<void> startShopping(WidgetTester tester, TestRuntime f) async {
  await startTasks(tester, f);
  await tester.tap(find.text('Home').last);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Shopping'));
}

Future<void> closeShopping(WidgetTester tester, TestRuntime f) async {
  await tester.pumpWidget(const SizedBox());
  await f.auth.events.close();
}

void main() {
  test('inventory-prefilled forms retain their own drafts', () async {
    final server = ShoppingServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.shopping;
    await vm.saveDraft('new', {'title': 'General groceries'}, vm.scope);
    final form = ShoppingFormViewModel(
      vm,
      prefill: {
        'title': 'Cooking Oil',
        'unit': 'L',
        'linked_inventory_item_id': 'tap',
      },
    );
    expect(form.fields['title'], 'Cooking Oil');
    form.update('quantity', '2.5');
    final restored = ShoppingFormViewModel(
      vm,
      prefill: {
        'title': 'Cooking Oil',
        'unit': 'L',
        'linked_inventory_item_id': 'tap',
      },
    );
    expect(restored.fields['quantity'], '2.5');
    expect(vm.draft('new')?['title'], 'General groceries');
    form.dispose();
    restored.dispose();
    await f.dispose();
  });
  test('shopping parsing and safe progress reuse task priority and status', () {
    final item = ShoppingItem(shoppingRow());
    expect(item.kind, TaskKind.shopping);
    expect(item.priority, TaskPriority.urgent);
    expect(item.quantity, '5');
    expect(const ShoppingSummary({}).progress, 0);
    expect(const ShoppingSummary({'total': 6, 'purchased': 3}).progress, .5);
    expect(
      () => ShoppingItem({...shoppingRow(), 'status': 'completed'}),
      throwsFormatException,
    );
  });
  test(
    'creation and duplicate awareness keep one parent per explicit request',
    () async {
      final server = ShoppingServer(), f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.shopping,
          form = ShoppingFormViewModel(
            f.runtime.shopping,
            prefill: {
              'title': 'Oil',
              'quantity': '5',
              'unit': 'L',
              'linked_inventory_item_id': 'tap',
            },
          );
      expect(await form.submit(), null);
      expect(form.duplicates, hasLength(1));
      expect(server.shopping, hasLength(1));
      final created = await form.submit(allowDuplicate: true);
      expect(created?.kind, TaskKind.shopping);
      expect(server.shopping, hasLength(2));
      expect(vm.draft('new'), null);
      form.dispose();
      await f.dispose();
    },
  );
  test('claim purchase stock retry and undo use explicit revision-protected actions', () async {
    final server = ShoppingServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.shopping;
    final claimed = await vm.action(ShoppingItem(shoppingRow()), 'claim');
    expect(claimed?.assignedTo, 'user-a');
    final bought = await vm.action(
      claimed!,
      'purchase',
      fields: {'purchase_price': '1200.50', 'currency_code': 'PKR'},
    );
    expect(bought?.purchased, true);
    expect(server.stock, .5);
    expect(await vm.apply(bought!), true);
    expect(await vm.apply(bought), true);
    expect(server.stock, 5.5);
    final current = await vm.open('oil');
    expect((await vm.action(current!, 'undo-purchase'))?.purchased, false);
    expect(server.stock, 5.5);
    expect(server.purchases, hasLength(1));
    await f.dispose();
  });
  test(
    'inventory failure preserves purchased state and permits safe retry',
    () async {
      final server = ShoppingServer()..failInventory = true,
          f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.shopping;
      final bought = await vm.action(ShoppingItem(shoppingRow()), 'purchase');
      expect(await vm.apply(bought!), false);
      expect(server.shopping['oil']!['status'], 'completed');
      expect(server.stock, .5);
      server.failInventory = false;
      expect(await vm.apply(bought), true);
      expect(server.stock, 5.5);
      await f.dispose();
    },
  );
  test(
    'offline cached list history and drafts never replay purchases',
    () async {
      final server = ShoppingServer(), f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.shopping;
      await vm.load();
      await vm.open('oil');
      await vm.loadHistory();
      server.offline = true;
      await vm.load();
      await vm.loadHistory();
      expect(vm.cached, true);
      expect(vm.historyCached, true);
      final form = ShoppingFormViewModel(vm);
      form.update('title', 'Offline eggs');
      expect(await form.submit(), null);
      expect(vm.draft('new')?['title'], 'Offline eggs');
      final writes = server.requests.where((r) => r.method == 'POST').length;
      server.offline = false;
      await vm.load();
      expect(server.requests.where((r) => r.method == 'POST').length, writes);
      form.dispose();
      await f.dispose();
    },
  );
  test(
    'stale edits retain original draft revision and reload server state',
    () async {
      final server = ShoppingServer(), f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.shopping;
      final form = ShoppingFormViewModel(
        vm,
        initial: ShoppingItem(shoppingRow()),
      );
      form.update('title', 'My oil');
      server.shopping['oil']!['revision'] = 2;
      expect(await form.submit(), null);
      expect(form.error, 'revision_conflict');
      expect(vm.draft('oil')?['expected_revision'], 1);
      expect(server.shopping['oil']!['title'], 'Cooking Oil');
      form.dispose();
      await f.dispose();
    },
  );
  test(
    'old household actions and late responses cannot enter the new scope',
    () async {
      final server = ShoppingServer(), f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.shopping;
      final gate = Completer<http.Response>(), started = Completer<void>();
      server.overrideShopping = (request) {
        if (!started.isCompleted) started.complete();
        return gate.future;
      };
      final pending = vm.load();
      await started.future;
      await f.runtime.session.selectHousehold('b');
      gate.complete(
        response({
          'items': [shoppingRow()],
          'total': 1,
        }),
      );
      await pending;
      expect(vm.items, isEmpty);
      expect(await vm.action(ShoppingItem(shoppingRow()), 'claim'), null);
      expect(vm.draft('new'), null);
      await f.dispose();
    },
  );
  test('foreign household response is never shown or cached', () async {
    final server = ShoppingServer()..badHousehold = true,
        f = await fixture(server);
    await f.runtime.session.start();
    await f.runtime.shopping.load();
    expect(f.runtime.shopping.items, isEmpty);
    expect(
      f.runtime.store.preferences.getKeys().where(
        (e) => e.contains('cache.shopping'),
      ),
      isEmpty,
    );
    await f.dispose();
  });
  testWidgets(
    'narrow shopping list renders backend progress and purchase confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = ShoppingServer(), f = await fixture(server);
      await startShopping(tester, f);
      expect(find.text('Cooking Oil'), findsOneWidget);
      expect(find.text('0 of 1 items purchased'), findsOneWidget);
      await captureTask(tester, f, 'shopping-list');
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await captureTask(tester, f, 'shopping-purchase');
      await tapVisible(tester, find.text('Mark Purchased').last);
      expect(find.text('Update household inventory?'), findsOneWidget);
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(server.stock, .5);
      expect(find.text('1 of 1 items purchased'), findsOneWidget);
      await tapVisible(tester, find.byType(Checkbox).first);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(server.shopping['oil']!['status'], 'open');
      expect(server.purchases, hasLength(1));
      expect(tester.takeException(), null);
      await closeShopping(tester, f);
    },
  );
  testWidgets('empty list supports compact quick add with optional quantity', (
    tester,
  ) async {
    final server = ShoppingServer()..shopping.clear(),
        f = await fixture(server);
    await startShopping(tester, f);
    expect(find.textContaining('Your shopping list is empty'), findsOneWidget);
    await tapVisible(tester, find.text('Add Item'));
    await captureTask(tester, f, 'shopping-form');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name'),
      'Bread',
    );
    await tapVisible(tester, find.text('Add to List'));
    expect(server.shopping.values.single['title'], 'Bread');
    expect(server.shopping.values.single['quantity'], null);
    expect(tester.takeException(), null);
    await closeShopping(tester, f);
  });
  testWidgets(
    'responsibility claims and reassignment are confirmed by backend',
    (tester) async {
      final server = ShoppingServer(), f = await fixture(server);
      await startShopping(tester, f);
      await tapVisible(tester, find.text('Cooking Oil'));
      await tapVisible(tester, find.text('I’ll Buy This'));
      expect(server.shopping['oil']!['assigned_to'], 'user-a');
      await tapVisible(tester, find.text('Assign / Reassign'));
      await tester.tap(find.text('Unassign'));
      await tester.pumpAndSettle();
      expect(server.shopping['oil']!['assigned_to'], null);
      expect(tester.takeException(), null);
      await closeShopping(tester, f);
    },
  );

  testWidgets('shopping search and purchased filters use backend records', (
    tester,
  ) async {
    final server = ShoppingServer(), f = await fixture(server);
    await startShopping(tester, f);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search shopping items'),
      'Missing',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Cooking Oil'), findsNothing);
    expect(find.text('No shopping items match these filters.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search shopping items'),
      '',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Cooking Oil'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Purchased'));
    expect(find.text('Cooking Oil'), findsNothing);
    expect(
      server.requests.any((r) => r.url.queryParameters['view'] == 'purchased'),
      true,
    );
    expect(tester.takeException(), null);
    await closeShopping(tester, f);
  });

  testWidgets(
    'inventory prompt failure keeps purchase saved with a safe retry message',
    (tester) async {
      final server = ShoppingServer()..failInventory = true,
          f = await fixture(server);
      await startShopping(tester, f);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Mark Purchased').last);
      await tester.tap(find.text('Update Inventory'));
      await tester.pumpAndSettle();
      expect(server.shopping['oil']!['status'], 'completed');
      expect(server.stock, .5);
      expect(
        find.textContaining('The purchase remains saved.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await closeShopping(tester, f);
    },
  );

  testWidgets('loading and request failure recover through manual refresh', (
    tester,
  ) async {
    final server = ShoppingServer(), f = await fixture(server);
    final gate = Completer<http.Response>();
    server.overrideShopping = (request) => gate.future;
    await startTasks(tester, f);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Shopping'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Shopping'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    gate.complete(
      response({
        'error': {'code': 'unavailable'},
      }, 500),
    );
    await tester.pumpAndSettle();
    expect(f.runtime.shopping.error, isNotNull);
    expect(f.runtime.shopping.loading, false);
    server.overrideShopping = null;
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pumpAndSettle();
    expect(find.text('Cooking Oil'), findsOneWidget);
    expect(f.runtime.shopping.error, null);
    expect(tester.takeException(), null);
    await closeShopping(tester, f);
  });
}
