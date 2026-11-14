import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/notifications/services/push_service.dart';
import 'package:homecircle/features/dashboard/models/household_hub.dart';

import 'support/fakes.dart';
import 'shopping_test.dart' show ShoppingServer;
import 'tasks_test.dart'
    show response, taskRow, startTasks, tapVisible, captureTask;

const noticeId = '11111111-1111-4111-8111-111111111111';
const otherNotice = '22222222-2222-4222-8222-222222222222';

class FakePush extends NoPushService {
  @override
  bool get available => true;
  final targets = StreamController<String>.broadcast(sync: true);
  final foregrounds = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final taps = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  PushPermission status = PushPermission.denied;
  int permissionRequests = 0, deletions = 0;
  Map<String, dynamic>? initialPayload;
  @override
  Stream<String> get tokenChanges => targets.stream;
  @override
  Stream<Map<String, dynamic>> get foreground => foregrounds.stream;
  @override
  Stream<Map<String, dynamic>> get opened => taps.stream;
  @override
  Future<Map<String, dynamic>?> initial() async => initialPayload;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return status;
  }

  @override
  Future<String?> token() async => 'private-registration-target-123';
  @override
  Future<void> removeToken() async {
    deletions++;
  }

  @override
  Future<void> dispose() async {
    await targets.close();
    await foregrounds.close();
    await taps.close();
  }
}

class HubServer extends ShoppingServer {
  final notices = <String, Map<String, dynamic>>{};
  final activity = <Map<String, dynamic>>[];
  final preferences = <String, Map<String, dynamic>>{};
  final deviceBodies = <Map<String, dynamic>>[];
  bool empty = false, denied = false, foreign = false, failWrites = false;
  Completer<void>? holdDashboard;
  HubServer() {
    rows['repair-b'] = taskRow(
      id: 'repair-b',
      home: 'b',
      title: 'Home B repair',
    );
    notices[noticeId] = notice(noticeId, 'a', 'repair');
    notices[otherNotice] = notice(otherNotice, 'b', 'repair-b');
    for (var i = 0; i < 35; i++) {
      activity.add({
        'id': 'event-$i',
        'household_id': 'a',
        'actor_user_id': 'father',
        'actor_display_name': 'Father',
        'event_type': i.isEven ? 'completed' : 'created',
        'category': i.isEven ? 'repairs' : 'shopping',
        'entity_type': i.isEven ? 'task' : 'shopping',
        'entity_id': i.isEven ? 'repair' : 'oil',
        'title': 'Activity $i',
        'created_at': DateTime.utc(
          2026,
          11,
          14,
        ).subtract(Duration(minutes: i)).toIso8601String(),
        'metadata': <String, dynamic>{},
      });
    }
  }
  Map<String, dynamic> notice(String id, String home, String entity) => {
    'id': id,
    'recipient_user_id': 'user-a',
    'household_id': home,
    'event_type': 'task_assigned',
    'title': home == 'a' ? 'Repair assigned' : 'Home B update',
    'body': 'A household request has an update.',
    'related_entity_type': 'task',
    'related_entity_id': entity,
    'source_event_id': 'source-$id',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'read_at': null,
    'dismissed_at': null,
  };
  Map<String, dynamic> dashboard(String home) => {
    'household': {
      'id': home,
      'name': 'Home $home',
      'time_zone': 'Asia/Karachi',
    },
    'summary': {
      'pending_tasks': empty
          ? 0
          : home == 'a'
          ? 4
          : 1,
      'urgent_issues': empty ? 0 : 2,
      'shopping_items': empty ? 0 : 6,
      'low_stock_items': empty ? 0 : 3,
      'out_of_stock_items': empty ? 0 : 1,
      'overdue_tasks': empty ? 0 : 1,
      'my_tasks': empty ? 0 : 2,
    },
    'needs_attention': empty
        ? []
        : [
            {
              'id': home == 'a' ? 'repair' : 'repair-b',
              'household_id': home,
              'entity_type': 'task',
              'title': home == 'a' ? 'Bathroom tap leaking' : 'Home B repair',
              'task_type': 'repair',
              'priority': 'urgent',
              'status': 'open',
              'due_date': '2026-11-13',
              'assignee_name': 'Father',
              'rank': 0,
            },
          ],
    'upcoming_tasks': empty
        ? []
        : [
            {
              'id': 'repair',
              'household_id': home,
              'entity_type': 'task',
              'title': 'Service the washer',
              'task_type': 'repair',
              'priority': 'normal',
              'status': 'open',
              'due_date': '2026-11-16',
              'assignee_name': null,
              'rank': 6,
            },
          ],
    'recent_activity': empty
        ? []
        : activity.where((r) => r['household_id'] == home).take(3).toList(),
    'unread_notifications': notices.values
        .where(
          (r) =>
              r['household_id'] == home &&
              r['read_at'] == null &&
              r['dismissed_at'] == null,
        )
        .length,
    'has_records': !empty,
    'as_of_date': '2026-11-14',
    'refreshed_at': DateTime.now().toUtc().toIso8601String(),
  };
  bool isHub(String path) =>
      path.endsWith('/dashboard') ||
      path.endsWith('/activity') ||
      path.contains('/notifications') ||
      path.endsWith('/notification-preferences') ||
      path.contains('/devices/');
  @override
  Future<http.Response> call(http.Request request) async {
    final path = request.url.path;
    if (!isHub(path)) return super.call(request);
    requests.add(request);
    if (offline) throw http.ClientException('Offline');
    if (denied) {
      return response({
        'error': {'code': 'forbidden'},
      }, 403);
    }
    if (failWrites && request.method != 'GET') {
      throw http.ClientException('Write not confirmed');
    }
    final query = request.url.queryParameters,
        segments = request.url.pathSegments;
    final home = segments.contains('households')
        ? segments[3]
        : query['household_id'] ?? 'a';
    if (path.endsWith('/dashboard')) {
      if (home == 'a') await holdDashboard?.future;
      final value = dashboard(home);
      if (foreign) (value['household'] as Map)['id'] = 'foreign';
      return response(value);
    }
    if (path.endsWith('/activity')) {
      var values = activity.where((r) => r['household_id'] == home).toList();
      if (query['category'] != null) {
        values = values
            .where((r) => r['category'] == query['category'])
            .toList();
      }
      if (query['start'] != null) {
        values = values
            .where(
              (r) =>
                  !DateTime.parse(r['created_at'] as String)
                      .isBefore(DateTime.parse(query['start']!)),
            )
            .toList();
      }
      final skip = int.parse(query['cursor'] ?? '0');
      return response({
        'items': values.skip(skip).take(30).toList(),
        'cursor': values.length > skip + 30 ? '${skip + 30}' : null,
        'has_more': values.length > skip + 30,
      });
    }
    if (path.endsWith('/notification-preferences')) {
      final value = preferences.putIfAbsent(
        home,
        () => {
          'user_id': 'user-a',
          'household_id': home,
          for (final key in [
            'tasks_enabled',
            'shopping_enabled',
            'inventory_enabled',
            'chat_enabled',
            'mentions_enabled',
            'push_enabled',
          ])
            key: true,
        },
      );
      if (request.method == 'PATCH') {
        value.addAll(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return response(value);
    }
    if (path.contains('/devices/')) {
      deviceBodies.add({
        'method': request.method,
        ...jsonDecode(request.body) as Map<String, dynamic>,
      });
      return response({'id': 'device', 'revoked': true});
    }
    if (path.endsWith('/notifications')) {
      var values = notices.values
          .where((r) => r['household_id'] == home && r['dismissed_at'] == null)
          .toList();
      if (query['unread_only'] == 'true') {
        values = values.where((r) => r['read_at'] == null).toList();
      }
      return response({'items': values, 'cursor': null, 'has_more': false});
    }
    if (path.endsWith('/unread-count')) {
      return response({
        'count': notices.values
            .where(
              (r) =>
                  r['household_id'] == home &&
                  r['read_at'] == null &&
                  r['dismissed_at'] == null,
            )
            .length,
      });
    }
    if (path.endsWith('/mark-all-read')) {
      final h = (jsonDecode(request.body) as Map)['household_id'];
      for (final row in notices.values) {
        if (row['household_id'] == h) row['read_at'] = '2026-11-14T10:00:00Z';
      }
      return response({'updated': 1});
    }
    final id = segments[3], row = notices[id];
    if (row == null) {
      return response({
        'error': {'code': 'not_found'},
      }, 404);
    }
    if (request.method == 'PATCH') {
      row[segments.last == 'read' ? 'read_at' : 'dismissed_at'] =
          '2026-11-14T10:00:00Z';
    }
    return response(row);
  }
}

Future<TestRuntime> hubFixture(
  HubServer server, {
  FakePush? push,
  MemoryChatCache? cache,
  bool start = true,
}) async {
  final f = await createTestRuntime(
    identity: const AuthIdentity(id: 'user-a'),
    preferences: {'homecircle.user.user-a.active': 'a'},
    respond: server.call,
    push: push,
    chatCache: cache,
  );
  f.runtime.notifications;
  if (start) await f.runtime.session.start();
  return f;
}

Future<void> eventually(bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), true);
}

Future<void> startHub(WidgetTester tester, TestRuntime f) async {
  await startTasks(tester, f);
  await tester.tap(find.text('Home').last);
  await tester.pumpAndSettle();
}

Future<void> closeHub(WidgetTester tester, TestRuntime f) async {
  await tester.pumpWidget(const SizedBox());
  await f.auth.events.close();
}

void main() {
  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('major tabs fit $width logical pixels at large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final f = await hubFixture(HubServer());
      await startHub(tester, f);
      expect(tester.takeException(), null);
      for (final tab in ['Inventory', 'Tasks', 'Chat', 'Profile']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null, reason: '$tab at $width');
      }
      await closeHub(tester, f);
    });
  }

  testWidgets('active Profile route opens notification preferences', (
    tester,
  ) async {
    final f = await hubFixture(HubServer());
    await startHub(tester, f);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Notification Settings'));
    expect(
      find.textContaining('In-app notifications are saved'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
    await closeHub(tester, f);
  });

  test(
    'dashboard reads one aggregate endpoint and rejects foreign household data',
    () async {
      final server = HubServer(),
          f = await hubFixture(server),
          vm = f.runtime.dashboard;
      await vm.open();
      expect(vm.snapshot!.count('pending_tasks'), 4);
      expect(vm.snapshot!.count('low_stock_items'), 3);
      expect(
        server.requests.where((r) => r.url.path.endsWith('/dashboard')),
        hasLength(1),
      );
      server.foreign = true;
      await vm.load();
      expect(vm.error, 'invalid_response');
      await f.dispose();
    },
  );
  test(
    'dashboard cache is scoped and authorization failure does not fall back',
    () async {
      final server = HubServer(),
          f = await hubFixture(server),
          vm = f.runtime.dashboard;
      await vm.open();
      server.offline = true;
      await vm.load();
      expect(vm.cached, true);
      expect(vm.savedAt, isNotNull);
      server.offline = false;
      server.denied = true;
      await vm.load();
      expect(vm.snapshot, null);
      expect(vm.cached, false);
      await f.dispose();
    },
  );
  test('household switching rejects an old aggregate response and resets activity filters', () async {
    final server = HubServer(),
        f = await hubFixture(server),
        vm = f.runtime.dashboard;
    server.holdDashboard = Completer<void>();
    final pending = vm.open();
    await Future<void>.delayed(Duration.zero);
    f.runtime.activity.category = 'repairs';
    f.runtime.notifications.destination = const HubDestination(
      'taskDetails',
      id: 'repair',
    );
    await f.runtime.session.selectHousehold('b');
    await eventually(() => vm.snapshot != null);
    server.holdDashboard!.complete();
    await pending;
    expect(vm.home, 'b');
    expect(vm.snapshot!.count('pending_tasks'), 1);
    expect(f.runtime.activity.category, 'all');
    expect(f.runtime.notifications.destination, null);
    await f.dispose();
  });
  test(
    'activity filters pagination and cached offline state retain unique events',
    () async {
      final server = HubServer(),
          f = await hubFixture(server),
          vm = f.runtime.activity;
      await vm.open();
      expect(vm.items, hasLength(30));
      expect(vm.more, true);
      await vm.page(next: true);
      expect(vm.items, hasLength(35));
      await vm.filter('repairs');
      expect(vm.items.every((r) => r['category'] == 'repairs'), true);
      server.offline = true;
      await vm.load();
      expect(vm.cached, true);
      expect(vm.items, isNotEmpty);
      await f.dispose();
    },
  );
  test('read actions need confirmation and unread counts are cached without false sync', () async {
    final server = HubServer(),
        f = await hubFixture(server),
        vm = f.runtime.notifications;
    await vm.open();
    expect(vm.unread, 1);
    server.failWrites = true;
    expect(await vm.action(noticeId, 'read'), false);
    expect(vm.items.single['read_at'], null);
    server.failWrites = false;
    expect(await vm.action(noticeId, 'read'), true);
    expect(vm.unread, 0);
    server.offline = true;
    await vm.load();
    expect(vm.cached, true);
    expect(vm.unread, 0);
    await f.dispose();
  });
  test(
    'preferences persist through API and failed writes retain server state',
    () async {
      final server = HubServer(),
          f = await hubFixture(server),
          vm = f.runtime.notifications;
      await vm.loadPreferences();
      expect(await vm.setPreference('chat_enabled', false), true);
      expect(server.preferences['a']!['chat_enabled'], false);
      server.failWrites = true;
      expect(await vm.setPreference('chat_enabled', true), false);
      expect(vm.preferences['chat_enabled'], false);
      server.failWrites = false;
      await f.runtime.session.selectHousehold('b');
      await vm.loadPreferences();
      expect(vm.preferences['chat_enabled'], true);
      await f.dispose();
    },
  );
  test('push denial is not repeatedly prompted and in-app notifications still load', () async {
    final push = FakePush(),
        server = HubServer(),
        f = await hubFixture(server, push: push),
        vm = f.runtime.notifications;
    await vm.preparePush();
    expect(push.permissionRequests, 0);
    await vm.requestPermission();
    await vm.requestPermission();
    expect(push.permissionRequests, 1);
    await vm.open();
    expect(vm.items, hasLength(1));
    expect(vm.permission, PushPermission.denied);
    await f.dispose();
  });
  test('authorized token registration rotation and logout use authenticated endpoints', () async {
    final push = FakePush()..status = PushPermission.authorized,
        server = HubServer(),
        f = await hubFixture(server, push: push);
    await eventually(() => server.deviceBodies.isNotEmpty);
    push.targets.add('rotated-registration-target-456');
    await eventually(
      () => server.deviceBodies.any(
        (b) => b['token'] == 'rotated-registration-target-456',
      ),
    );
    expect(
      f.runtime.store.preferences
          .getKeys()
          .map((key) => f.runtime.store.preferences.get(key))
          .join(),
      isNot(contains('registration-target')),
    );
    await f.runtime.session.logout();
    expect(server.deviceBodies.last['method'], 'DELETE');
    expect(push.deletions, 1);
    expect(
      (f.runtime.chat.repository.cache as MemoryChatCache).values,
      isEmpty,
    );
    await f.dispose();
  });
  test('untrusted push household is ignored in favor of authorized notification lookup', () async {
    final server = HubServer(),
        push = FakePush(),
        f = await hubFixture(server, push: push),
        vm = f.runtime.notifications;
    vm.acceptPush({'notification_id': otherNotice, 'household_id': 'attacker'});
    await eventually(() => vm.destination != null);
    expect(f.runtime.session.activeHousehold!.id, 'b');
    expect(vm.destination!.route, 'taskDetails');
    expect(vm.destination!.id, 'repair-b');
    await f.dispose();
  });
  test('terminated launch waits for restored session and drops malformed destinations', () async {
    final push = FakePush()..initialPayload = {'notification_id': noticeId},
        server = HubServer(),
        f = await hubFixture(server, push: push, start: false),
        vm = f.runtime.notifications;
    await Future<void>.delayed(Duration.zero);
    expect(vm.destination, null);
    await f.runtime.session.start();
    await eventually(() => vm.destination != null);
    expect(vm.takeDestination()!.id, 'repair');
    vm.acceptPush({'notification_id': 'https://attacker.test'});
    expect(vm.pendingId, null);
    await f.dispose();
  });
  test(
    'unavailable or foreign related records do not produce a destination',
    () async {
      final server = HubServer(),
          f = await hubFixture(server),
          vm = f.runtime.notifications;
      server.rows['repair']!['deleted_at'] = '2026-11-14T10:00:00Z';
      vm.acceptPush({'notification_id': noticeId});
      await eventually(() => !vm.resolving);
      expect(vm.destination, null);
      expect(vm.error, 'not_found');
      expect(await vm.resolveEntity('task', 'repair-b', 'a'), null);
      await f.dispose();
    },
  );
  testWidgets(
    'dashboard uses live counts and quick actions on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = HubServer(), f = await hubFixture(server);
      await startHub(tester, f);
      await captureTask(tester, f, 'dashboard');
      expect(find.text('Your home at a glance'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tapVisible(tester, find.text('Report Issue'));
      expect(find.text('Create Request'), findsWidgets);
      expect(f.runtime.tasks.ready, true);
      expect(tester.takeException(), null);
      await closeHub(tester, f);
    },
  );
  testWidgets('empty dashboard shows first-item action without sample cards', (
    tester,
  ) async {
    final server = HubServer()..empty = true, f = await hubFixture(server);
    await startHub(tester, f);
    await tester.scrollUntilVisible(
      find.text('Your home starts here!'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bathroom tap leaking'), findsNothing);
    expect(find.text('Add First Item'), findsOneWidget);
    expect(tester.takeException(), null);
    await closeHub(tester, f);
  });
  testWidgets('activity timeline filters and paginates real event responses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = HubServer(), f = await hubFixture(server);
    await startHub(tester, f);
    await tapVisible(tester, find.text('Family Activity'));
    await captureTask(tester, f, 'family-activity');
    expect(find.text("See what's been happening at home."), findsOneWidget);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    expect(find.text('No matching activity yet.'), findsOneWidget);
    expect(tester.takeException(), null);
    await closeHub(tester, f);
  });
  testWidgets(
    'notification center marks read and settings explain denied permission',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = HubServer(),
          push = FakePush(),
          f = await hubFixture(server, push: push);
      await startHub(tester, f);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      await captureTask(tester, f, 'notifications');
      expect(find.text('Repair assigned'), findsOneWidget);
      await tester.tap(find.text('Mark All as Read'));
      await tester.pumpAndSettle();
      expect(server.notices[noticeId]!['read_at'], isNotNull);
      await tester.tap(find.byTooltip('Notification Settings'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('In-app notifications are saved'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Device notifications are disabled'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await closeHub(tester, f);
    },
  );
  testWidgets(
    'foreground notification opens its authorized household destination',
    (tester) async {
      final server = HubServer(),
          push = FakePush(),
          f = await hubFixture(server, push: push);
      await startHub(tester, f);
      push.foregrounds.add({
        'notification_id': otherNotice,
        'household_id': 'untrusted',
      });
      expect(f.runtime.notifications.ready, true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('A household update is available.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Open'));
      await tester.pumpAndSettle();
      expect(f.runtime.session.activeHousehold!.id, 'b');
      expect(find.text('Home B repair'), findsWidgets);
      expect(tester.takeException(), null);
      await closeHub(tester, f);
    },
  );
}
