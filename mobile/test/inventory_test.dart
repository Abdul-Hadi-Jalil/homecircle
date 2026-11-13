import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:homecircle/app.dart';
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/inventory/models/inventory_item.dart';
import 'package:homecircle/features/inventory/viewmodels/inventory_view_model.dart';
import 'package:homecircle/features/inventory/views/inventory_views.dart';

import 'support/fakes.dart';

Map<String, dynamic> inventoryRow({
  String household = 'a',
  String name = 'Rice',
  int revision = 2,
  bool archived = false,
}) => {
  'id': 'rice',
  'household_id': household,
  'name': name,
  'item_type': 'consumable',
  'quantity': '3.125',
  'unit': 'kg',
  'minimum_quantity': '1',
  'stock_status': 'available',
  'condition': null,
  'category_id': null,
  'category_name': null,
  'photo_path': null,
  'location': 'Pantry',
  'notes': '',
  'revision': revision,
  'created_at': '2026-11-13T08:00:00Z',
  'updated_at': '2026-11-13T08:00:00Z',
  'deleted_at': archived ? '2026-11-13T08:00:00Z' : null,
};

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

class InventoryServer {
  bool offline = false, conflict = false;
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request)? listOverride;
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (!path.contains('/inventory')) {
      return householdResponse(request, [membership('a'), membership('b')]);
    }
    if (offline) throw http.ClientException('offline');
    final household = request.url.pathSegments[3];
    if (path.endsWith('/categories')) return jsonResponse([]);
    if (path.endsWith('/summary')) {
      return jsonResponse({
        'total': 1,
        'available': 1,
        'low_stock': 0,
        'out_of_stock': 0,
        'working': 0,
        'needs_repair': 0,
        'broken': 0,
      });
    }
    if (path.endsWith('/activity')) {
      return jsonResponse({
        'items': [
          {
            'id': 'event',
            'action': 'quantity_changed',
            'actor_name': 'Alex',
            'created_at': '2026-11-13',
            'changes': {
              'quantity': {'before': '2', 'after': '3.125'},
            },
          },
        ],
        'page': 1,
        'page_size': 20,
      });
    }
    if (request.method == 'GET' && path.endsWith('/inventory')) {
      if (listOverride != null) return listOverride!(request);
      return jsonResponse({
        'items': [
          inventoryRow(
            household: household,
            archived: request.url.queryParameters['archived'] == 'true',
          ),
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
      });
    }
    if (request.method == 'GET') {
      return jsonResponse(inventoryRow(household: household));
    }
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'revision_conflict'},
      }, 409);
    }
    return jsonResponse(inventoryRow(household: household, revision: 3));
  }
}

Future<TestRuntime> inventoryFixture(InventoryServer server) =>
    createTestRuntime(
      identity: const AuthIdentity(id: 'user-a'),
      preferences: {'homecircle.user.user-a.active': 'a'},
      respond: server.respond,
    );

Future<void> captureInventory(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (!const bool.fromEnvironment('CAPTURE_INVENTORY')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final rendered = await boundary.toImage();
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    await File('../.tmp/inventory-$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    rendered.dispose();
  });
}

void main() {
  test(
    'a response started before a write cannot restore stale cached data',
    () async {
      final server = InventoryServer(), response = Completer<http.Response>();
      server.listOverride = (_) => response.future;
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      final vm = fixture.runtime.inventory;
      final reading = vm.load();
      await Future<void>.delayed(Duration.zero);
      await vm.quantity(InventoryItem(inventoryRow()), 'increase', '1');
      response.complete(
        jsonResponse({
          'items': [inventoryRow()],
          'total': 1,
          'page': 1,
          'page_size': 20,
        }),
      );
      await reading;
      expect(vm.item?.revision, 3);
      expect(vm.items, isEmpty);
      expect(
        fixture.runtime.store.preferences.getKeys().where(
          (key) => key.contains('.cache.inventory.'),
        ),
        isEmpty,
      );
      await fixture.dispose();
    },
  );

  test(
    'failed offline save keeps its draft and reconnect never replays it',
    () async {
      final server = InventoryServer();
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      final vm = fixture.runtime.inventory;
      await vm.saveDraft('new', {'name': 'Offline draft'});
      server.offline = true;
      expect(await vm.save(null, {'name': 'Offline draft'}), null);
      expect(vm.draft('new')?['name'], 'Offline draft');
      final writes = server.requests.where((r) => r.method == 'POST').length;
      server.offline = false;
      await vm.load();
      expect(server.requests.where((r) => r.method == 'POST').length, writes);
      await fixture.dispose();
    },
  );
  test(
    'old-household actions cannot be sent in a new household scope',
    () async {
      final server = InventoryServer();
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      final vm = fixture.runtime.inventory;
      final selected = InventoryItem(inventoryRow());
      await fixture.runtime.session.selectHousehold('b');
      final count = server.requests.length;
      expect(await vm.quantity(selected, 'increase', '1'), null);
      expect(await vm.archive(selected), null);
      expect(await vm.upload(selected, Uint8List.fromList([1, 2, 3])), null);
      expect(server.requests.length, count);
      await fixture.dispose();
    },
  );

  test(
    'photo requests carry revisions and bytes without caching image data',
    () async {
      final server = InventoryServer();
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      final vm = fixture.runtime.inventory;
      await vm.load();
      final selected = InventoryItem(inventoryRow());
      await vm.upload(selected, Uint8List.fromList([1, 2, 3]));
      expect(server.requests.last.method, 'PUT');
      expect(jsonDecode(server.requests.last.body), {
        'expected_revision': 2,
        'data_base64': 'AQID',
      });
      expect(
        fixture.runtime.store.preferences.getKeys().where(
          (key) => key.contains('.cache.inventory.'),
        ),
        isEmpty,
      );
      await vm.removePhoto(selected);
      expect(server.requests.last.url.path, endsWith('/rice/photo'));
      expect(
        server.requests.last.url.queryParameters['expected_revision'],
        '2',
      );
      await fixture.dispose();
    },
  );

  test(
    'malformed cross-household response is never cached or displayed',
    () async {
      final server = InventoryServer();
      server.listOverride = (_) async => jsonResponse({
        'items': [inventoryRow(household: 'b')],
        'total': 1,
        'page': 1,
        'page_size': 20,
      });
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      await fixture.runtime.inventory.load();
      expect(fixture.runtime.inventory.items, isEmpty);
      expect(
        fixture.runtime.store.preferences.getKeys().where(
          (key) => key.contains('.cache.inventory.'),
        ),
        isEmpty,
      );
      await fixture.dispose();
    },
  );

  testWidgets('durable form sends correct type fields to the API', (
    tester,
  ) async {
    final server = InventoryServer();
    final fixture = await inventoryFixture(server);
    await tester.pumpWidget(HomeCircleApp(runtime: fixture.runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add inventory item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name'),
      'Washing machine',
    );
    await tester.ensureVisible(
      find.widgetWithText(DropdownButtonFormField<String>, 'Item type'),
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Item type'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durable').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Quantity'), findsNothing);
    await tester.ensureVisible(find.text('Save item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    final request = server.requests.singleWhere(
      (r) => r.method == 'POST' && r.url.path.endsWith('/inventory'),
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['item_type'], 'durable');
    expect(body['condition'], 'working');
    expect(body['quantity'], null);
    expect(body['unit'], null);
    expect(fixture.runtime.inventory.draft('new'), null);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await fixture.auth.events.close();
  });
  test(
    'quantity validation preserves decimal precision and rejects unsafe input',
    () {
      expect(quantityError('0.125'), null);
      for (final value in ['-1', 'NaN', '1.0001', '1000000000000', '']) {
        expect(quantityError(value), isNotNull);
      }
      expect(quantityError('', optional: true), null);
    },
  );

  test(
    'cached reading and drafts stay within validated user and household scope',
    () async {
      final server = InventoryServer();
      final actual = await inventoryFixture(server);
      await actual.runtime.session.start();
      final vm = actual.runtime.inventory;
      await vm.load();
      expect(vm.items.single.quantity, '3.125');
      await vm.saveDraft('new', {'name': 'Draft in A'});
      server.offline = true;
      await vm.load();
      expect(vm.cached, true);
      await vm.open('rice');
      expect(vm.item?.name, 'Rice');
      expect(vm.cached, true);
      await actual.runtime.session.selectHousehold('b');
      expect(vm.items, isEmpty);
      expect(vm.draft('new'), null);
      await vm.load();
      expect(vm.items, isEmpty);
      await actual.runtime.session.logout();
      expect(
        actual.runtime.store.preferences.getKeys().where(
          (key) => key.startsWith('homecircle.user.user-a.'),
        ),
        isEmpty,
      );
      await actual.dispose();
    },
  );

  test(
    'late inventory response cannot refill a switched or logged-out scope',
    () async {
      final server = InventoryServer(), response = Completer<http.Response>();
      server.listOverride = (_) => response.future;
      final fixture = await inventoryFixture(server);
      await fixture.runtime.session.start();
      final vm = fixture.runtime.inventory, pending = vm.load();
      await Future<void>.delayed(Duration.zero);
      await fixture.runtime.session.selectHousehold('b');
      response.complete(
        jsonResponse({
          'items': [inventoryRow()],
          'total': 1,
          'page': 1,
          'page_size': 20,
        }),
      );
      await pending;
      expect(vm.items, isEmpty);
      expect(
        fixture.runtime.store.preferences.getKeys().where(
          (key) => key.contains('.cache.inventory.'),
        ),
        isEmpty,
      );
      await fixture.dispose();
    },
  );

  test('only latest search response is displayed', () async {
    final server = InventoryServer(), first = Completer<http.Response>();
    server.listOverride = (request) async =>
        request.url.queryParameters['search'] == 'old'
        ? first.future
        : jsonResponse({
            'items': [inventoryRow(name: 'Latest')],
            'total': 1,
            'page': 1,
            'page_size': 20,
          });
    final fixture = await inventoryFixture(server);
    await fixture.runtime.session.start();
    final vm = fixture.runtime.inventory;
    vm.filters = {'search': 'old'};
    final pending = vm.load();
    await Future<void>.delayed(Duration.zero);
    vm.filters = {'search': 'new'};
    await vm.load();
    first.complete(
      jsonResponse({
        'items': [inventoryRow(name: 'Old')],
        'total': 1,
        'page': 1,
        'page_size': 20,
      }),
    );
    await pending;
    expect(vm.items.single.name, 'Latest');
    await fixture.dispose();
  });

  test('absolute quantity carries revision and conflicts retain the original state', () async {
    final server = InventoryServer();
    final actual = await inventoryFixture(server);
    await actual.runtime.session.start();
    final vm = actual.runtime.inventory;
    await vm.open('rice');
    final selected = vm.item!;
    server.conflict = true;
    expect(await vm.quantity(selected, 'set', '0.125'), null);
    expect(vm.item!.revision, 2);
    expect(vm.error, contains('This item changed'));
    final request = server.requests.last;
    expect(request.url.path, '/api/v1/households/a/inventory/rice/quantity');
    expect(jsonDecode(request.body), {
      'operation': 'set',
      'amount': '0.125',
      'expected_revision': 2,
    });
    server.conflict = false;
    await vm.quantity(selected, 'increase', '0.001');
    expect(jsonDecode(server.requests.last.body), {
      'operation': 'increase',
      'amount': '0.001',
    });
    await actual.dispose();
  });

  test(
    'archive and restore use revision-protected real endpoint paths',
    () async {
      final server = InventoryServer();
      final actual = await inventoryFixture(server);
      await actual.runtime.session.start();
      final vm = actual.runtime.inventory;
      await vm.archive(InventoryItem(inventoryRow()));
      expect(server.requests.last.method, 'DELETE');
      expect(
        server.requests.last.url.queryParameters['expected_revision'],
        '2',
      );
      await vm.archive(InventoryItem(inventoryRow(archived: true)));
      expect(server.requests.last.url.path, endsWith('/rice/restore'));
      expect(jsonDecode(server.requests.last.body), {'expected_revision': 2});
      await actual.dispose();
    },
  );

  testWidgets('inventory overview and filters work at narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = InventoryServer();
    final actual = await inventoryFixture(server);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: HomeCircleApp(runtime: actual.runtime),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    await captureInventory(tester, captureKey, 'overview');
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Storage location (exact match)'),
      'Pantry',
    );
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      server.requests.where(
        (r) => r.url.queryParameters['location'] == 'Pantry',
      ),
      isNotEmpty,
    );
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(
      server.requests.where((r) => r.url.queryParameters['archived'] == 'true'),
      isNotEmpty,
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await actual.auth.events.close();
  });

  testWidgets(
    'details quantity sheet validates then sends a real API mutation',
    (tester) async {
      final server = InventoryServer();
      final actual = await inventoryFixture(server);
      await tester.pumpWidget(HomeCircleApp(runtime: actual.runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      expect(actual.runtime.inventory.activity.single['actor_name'], 'Alex');
      await tester.ensureVisible(find.text('Update quantity'));
      await tester.tap(find.text('Update quantity'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '-1');
      await tester.tap(find.text('Save quantity'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a nonnegative'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '0.125');
      await tester.tap(find.text('Save quantity'));
      await tester.pumpAndSettle();
      expect(
        server.requests.where(
          (r) => r.method == 'PATCH' && r.url.path.endsWith('/quantity'),
        ),
        hasLength(1),
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await actual.auth.events.close();
    },
  );

  testWidgets('new-item form persists drafts without sending offline writes', (
    tester,
  ) async {
    final server = InventoryServer();
    final actual = await inventoryFixture(server);
    await tester.pumpWidget(HomeCircleApp(runtime: actual.runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add inventory item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name'),
      'Offline draft',
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(InventoryEditor));
    final vm = context.read<InventoryViewModel>();
    expect(vm.draft('new')?['name'], 'Offline draft');
    expect(
      server.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/inventory'),
      ),
      isEmpty,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add inventory item'));
    await tester.pumpAndSettle();
    expect(find.text('Offline draft'), findsOneWidget);
    expect(find.text('Your saved draft has been restored.'), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await actual.auth.events.close();
  });
}
