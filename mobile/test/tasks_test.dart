import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/app.dart';
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/tasks/models/household_task.dart';
import 'package:homecircle/features/tasks/models/task_comment.dart';
import 'package:homecircle/features/tasks/viewmodels/task_form_view_model.dart';

import 'support/fakes.dart';

Map<String, dynamic> taskRow({
  String id = 'repair',
  String home = 'a',
  String type = 'repair',
  String status = 'open',
  String title = 'Bathroom tap leak',
  int revision = 1,
}) => {
  'id': id,
  'household_id': home,
  'task_type': type,
  'title': title,
  'description': 'Replace the leaking washer.',
  'priority': 'urgent',
  'status': status,
  'created_by': 'user-a',
  'creator_name': 'Arham',
  'assigned_to': null,
  'assignee_name': null,
  'updated_by': 'user-a',
  'due_date': '2026-01-01',
  'location': 'Bathroom',
  'linked_inventory_item_id': type == 'repair' ? 'tap' : null,
  'linked_inventory_name': type == 'repair' ? 'Bathroom tap' : null,
  'linked_inventory_type': type == 'repair' ? 'durable' : null,
  'completion_note': null,
  'completed_at': null,
  'cancelled_at': null,
  'revision': revision,
  'created_at': '2026-11-14T08:00:00Z',
  'updated_at': '2026-11-14T08:00:00Z',
  'deleted_at': null,
};
http.Response response(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

class TaskServer {
  TaskServer() {
    rows['repair'] = taskRow();
  }
  final rows = <String, Map<String, dynamic>>{},
      comments = <Map<String, dynamic>>[],
      events = <Map<String, dynamic>>[],
      attachments = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  bool offline = false, failInventory = false;
  int inventoryWrites = 0, inventoryRevision = 1;
  String inventoryCondition = 'broken';
  Future<http.Response> Function(http.Request)? listOverride;
  final members = [
    for (final name in [
      ('user-a', 'Arham'),
      ('father', 'Father'),
      ('ali', 'Ali'),
      ('sarah', 'Sarah'),
    ])
      {
        'user_id': name.$1,
        'display_name': name.$2,
        'avatar_path': null,
        'role': 'member',
        'joined_at': '2026-11-14T08:00:00Z',
      },
  ];
  Map<String, dynamic> inventoryRow(String home) => {
    'id': 'tap',
    'household_id': home,
    'name': 'Bathroom tap',
    'item_type': 'durable',
    'condition': inventoryCondition,
    'quantity': null,
    'unit': null,
    'minimum_quantity': null,
    'stock_status': null,
    'photo_path': null,
    'category_name': 'Bathroom',
    'location': 'Bathroom',
    'notes': '',
    'revision': inventoryRevision,
    'deleted_at': null,
    'updated_at': '2026-11-14T08:00:00Z',
  };
  Future<http.Response> call(http.Request request) async {
    requests.add(request);
    final p = request.url.path, s = request.url.pathSegments;
    if (p.endsWith('/members')) return response(members);
    if (!p.contains('/tasks') && !p.contains('/inventory')) {
      return householdResponse(request, [
        {...membership('a'), 'role': 'member'},
        {...membership('b'), 'role': 'member'},
      ]);
    }
    if (offline) throw http.ClientException('offline');
    final home = s[3];
    if (p.contains('/inventory')) {
      if (p.endsWith('/tasks')) {
        return response({
          'items': rows.values
              .where(
                (r) =>
                    r['household_id'] == home &&
                    r['linked_inventory_item_id'] == 'tap',
              )
              .toList(),
          'total': 1,
          'page': 1,
          'page_size': 5,
        });
      }
      if (p.endsWith('/activity')) {
        return response({'items': [], 'page': 1, 'page_size': 20});
      }
      if (request.method == 'PATCH') {
        inventoryWrites++;
        if (failInventory) {
          return response({
            'error': {'code': 'revision_conflict'},
          }, 409);
        }
        inventoryCondition = 'working';
        inventoryRevision++;
        return response(inventoryRow(home));
      }
      if (p.endsWith('/inventory')) {
        return response({
          'items': [inventoryRow(home)],
          'total': 1,
          'page': 1,
          'page_size': 20,
        });
      }
      return response(inventoryRow(home));
    }
    if (p.endsWith('/summary')) {
      return response({
        for (final status in [
          'open',
          'in_progress',
          'blocked',
          'completed',
          'cancelled',
        ])
          status: rows.values
              .where(
                (r) =>
                    r['household_id'] == home &&
                    r['deleted_at'] == null &&
                    r['status'] == status,
              )
              .length,
        'total': rows.length,
        'overdue': 0,
      });
    }
    if (p.endsWith('/tasks')) {
      if (request.method == 'GET') {
        if (listOverride != null) return listOverride!(request);
        final q = request.url.queryParameters;
        final selected = rows.values
            .where(
              (r) =>
                  r['household_id'] == home &&
                  (q['archived'] == 'true'
                      ? r['deleted_at'] != null
                      : r['deleted_at'] == null) &&
                  (!q.containsKey('search') ||
                      r['title'].toString().toLowerCase().contains(
                        q['search']!.toLowerCase(),
                      )) &&
                  (!q.containsKey('task_type') ||
                      r['task_type'] == q['task_type']) &&
                  (!q.containsKey('priority') ||
                      r['priority'] == q['priority']) &&
                  (!q.containsKey('status') || r['status'] == q['status']) &&
                  (q['assignment'] != 'unassigned' ||
                      r['assigned_to'] == null) &&
                  (q['assignment'] != 'me' || r['assigned_to'] == 'user-a'),
            )
            .toList();
        return response({
          'items': selected,
          'total': selected.length,
          'page': 1,
          'page_size': 20,
        });
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = 'task-${rows.length + 1}';
      final created = {
        ...taskRow(
          id: id,
          home: home,
          type: body['task_type'] as String,
          title: body['title'] as String,
        ),
        ...body,
      };
      rows[id] = created;
      return response(created, 201);
    }
    final id = s[5], row = rows[id];
    if (row == null || row['household_id'] != home) {
      return response({
        'error': {'code': 'not_found'},
      }, 404);
    }
    if (request.method == 'GET') {
      if (p.endsWith('/comments')) {
        return response({
          'items': comments
              .where((c) => c['task_id'] == id && c['deleted_at'] == null)
              .toList(),
          'page': 1,
          'page_size': 20,
        });
      }
      if (p.endsWith('/activity')) {
        return response({
          'items': events.reversed.toList(),
          'page': 1,
          'page_size': 20,
        });
      }
      if (p.endsWith('/attachments')) {
        return response({
          'items': attachments
              .where((a) => a['task_id'] == id && a['deleted_at'] == null)
              .toList(),
          'page': 1,
          'page_size': 20,
        });
      }
      if (p.endsWith('/url')) {
        return response({
          'url': 'https://storage.example.test/private.jpg?token=short',
          'expires_in': 60,
        });
      }
      return response(row);
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final expected =
        body['expected_revision'] ??
        int.tryParse(request.url.queryParameters['expected_revision'] ?? '');
    if (expected != row['revision']) {
      return response({
        'error': {'code': 'revision_conflict'},
      }, 409);
    }
    final action = s.length > 6 ? s[6] : '';
    if (action == 'comments') {
      Map<String, dynamic> comment;
      if (s.length == 7) {
        comment = {
          'id': 'comment-${comments.length + 1}',
          'household_id': home,
          'task_id': id,
          'author_user_id': 'user-a',
          'author_name': 'Arham',
          'body': body['body'],
          'revision': 1,
          'created_at': '2026-11-14T08:00:00Z',
          'updated_at': '2026-11-14T08:00:00Z',
          'deleted_at': null,
        };
        comments.add(comment);
      } else {
        comment = comments.singleWhere((c) => c['id'] == s[7]);
        if (request.method == 'DELETE') {
          comment['deleted_at'] = '2026-11-14T09:00:00Z';
        } else {
          comment['body'] = body['body'];
        }
        comment['revision'] = (comment['revision'] as int) + 1;
      }
      row['revision'] = (row['revision'] as int) + 1;
      return response(comment, s.length == 7 ? 201 : 200);
    }
    if (action == 'attachments' && request.method == 'POST') {
      final attachment = {
        'id': 'photo-${attachments.length + 1}',
        'household_id': home,
        'task_id': id,
        'comment_id': body['comment_id'],
        'uploaded_by': 'user-a',
        'content_type': 'image/jpeg',
        'size_bytes': 3,
        'created_at': '2026-11-14T08:00:00Z',
        'deleted_at': null,
      };
      attachments.add(attachment);
      row['revision'] = (row['revision'] as int) + 1;
      return response(attachment, 201);
    }
    if (action == 'assignment') {
      if (body['operation'] == 'claim' && row['assigned_to'] != null) {
        return response({
          'error': {'code': 'already_claimed'},
        }, 409);
      }
      row['assigned_to'] = body['operation'] == 'claim'
          ? 'user-a'
          : body['assigned_to'];
      row['assignee_name'] = members
          .where((m) => m['user_id'] == row['assigned_to'])
          .firstOrNull?['display_name'];
    } else if (action == 'status') {
      row['status'] = body['status'];
      row['completion_note'] = body['completion_note'];
      row['completed_at'] = body['status'] == 'completed'
          ? '2026-11-14T09:00:00Z'
          : null;
      row['cancelled_at'] = body['status'] == 'cancelled'
          ? '2026-11-14T09:00:00Z'
          : null;
    } else if (action == 'priority') {
      row['priority'] = body['priority'];
    } else if (action == 'restore') {
      row['deleted_at'] = null;
    } else if (action == 'attachments') {
      attachments.singleWhere((a) => a['id'] == s[7])['deleted_at'] =
          '2026-11-14T09:00:00Z';
    } else if (request.method == 'DELETE') {
      row['deleted_at'] = '2026-11-14T09:00:00Z';
    } else {
      row.addAll(body..remove('expected_revision'));
    }
    row['revision'] = (row['revision'] as int) + 1;
    events.add({
      'id': 'event-${events.length + 1}',
      'actor_user_id': 'user-a',
      'actor_name': 'Arham',
      'action': action == 'status'
          ? (row['status'] == 'completed'
                ? 'completed'
                : body['reopen'] == true
                ? 'reopened'
                : 'status_changed')
          : 'updated',
      'changes': <String, dynamic>{},
      'created_at': '2026-11-14T09:00:00Z',
    });
    return response(row);
  }
}

Future<TestRuntime> fixture(TaskServer server) => createTestRuntime(
  identity: const AuthIdentity(id: 'user-a'),
  preferences: {'homecircle.user.user-a.active': 'a'},
  respond: server.call,
);
final captureKeys = <TestRuntime, GlobalKey>{};
bool fontsLoaded = false;
Future<void> startTasks(WidgetTester tester, TestRuntime f) async {
  if (const bool.fromEnvironment('CAPTURE_TASKS') && !fontsLoaded) {
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT']!;
      final roboto = FontLoader('Roboto')
        ..addFont(
          File('$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await Future.wait([roboto.load(), icons.load()]);
      fontsLoaded = true;
    });
  }
  final key = GlobalKey();
  captureKeys[f] = key;
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: HomeCircleApp(runtime: f.runtime),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tasks').last);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester, TestRuntime f) async {
  await tester.pumpWidget(const SizedBox());
  await f.auth.events.close();
  captureKeys.remove(f);
}

Future<void> captureTask(
  WidgetTester tester,
  TestRuntime f,
  String name,
) async {
  if (!const bool.fromEnvironment('CAPTURE_TASKS')) return;
  await tester.runAsync(() async {
    final boundary =
        captureKeys[f]!.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final bitmap = await boundary.toImage();
    final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    await File('../.tmp/tasks-$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    bitmap.dispose();
  });
}

void main() {
  test('duplicate form submission produces only one create request', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    final form = TaskFormViewModel(vm);
    form.update('title', 'One request');
    final first = form.submit();
    expect(await form.submit(), null);
    expect(await first, isNotNull);
    expect(
      server.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/tasks'),
      ),
      hasLength(1),
    );
    form.dispose();
    await f.dispose();
  });
  test(
    'a General request uses the default normal priority and supports ownership',
    () async {
      final server = TaskServer(), f = await fixture(server);
      await f.runtime.session.start();
      final vm = f.runtime.tasks;
      final form = TaskFormViewModel(vm);
      form.update('title', 'Family request');
      final saved = await form.submit();
      expect(saved?.kind, TaskKind.general);
      expect(saved?.priority, TaskPriority.normal);
      expect((await vm.assign(saved!, 'claim', null))?.assignedTo, 'user-a');
      form.dispose();
      await f.dispose();
    },
  );
  test('a stale edit shows conflict and retains its local draft', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    final form = TaskFormViewModel(vm, initial: HouseholdTask(taskRow()));
    form.update('title', 'My draft');
    server.rows['repair']!['revision'] = 2;
    expect(await form.submit(), null);
    expect(vm.errorCode, 'revision_conflict');
    expect(vm.draft('repair')?['title'], 'My draft');
    expect(server.rows['repair']!['title'], 'Bathroom tap leak');
    form.dispose();
    await f.dispose();
  });
  testWidgets('editing a request updates the existing record', (tester) async {
    final server = TaskServer(), f = await fixture(server);
    await startTasks(tester, f);
    await tapVisible(tester, find.text('Bathroom tap leak'));
    await tapVisible(tester, find.text('Edit'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Bathroom tap inspection',
    );
    await tapVisible(tester, find.text('Save request'));
    expect(server.rows['repair']!['title'], 'Bathroom tap inspection');
    expect(server.rows.length, 1);
    expect(tester.takeException(), null);
    await close(tester, f);
  });
  testWidgets(
    'completed requests reopen explicitly and can be archived and restored',
    (tester) async {
      final server = TaskServer();
      server.rows['repair'] = {
        ...taskRow(status: 'completed'),
        'completed_at': '2026-11-14T08:00:00Z',
      };
      final f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Bathroom tap leak'));
      await tapVisible(tester, find.text('Reopen'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['status'], 'open');
      expect(server.rows['repair']!['completed_at'], null);
      await tapVisible(tester, find.text('Archive'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['deleted_at'], isNotNull);
      await tapVisible(tester, find.text('Restore'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['deleted_at'], null);
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  test(
    'typed task models distinguish priority/status and calendar overdue dates',
    () {
      final task = HouseholdTask(taskRow());
      expect(task.kind, TaskKind.repair);
      expect(task.priority, TaskPriority.urgent);
      expect(task.status, TaskStatus.open);
      expect(task.overdue(DateTime(2026, 2, 1)), true);
      expect(task.overdue(DateTime(2026, 1, 1)), false);
      expect(
        HouseholdTask(taskRow(status: 'completed'))
            .overdue(DateTime(2026, 2, 1)),
        false,
      );
      expect(
        () => HouseholdTask({...taskRow(), 'priority': 'invalid'}),
        throwsArgumentError,
      );
    },
  );
  test('task create/edit retain expected revisions and clear only successful drafts', () async {
    final server = TaskServer();
    final actual = await fixture(server);
    await actual.runtime.session.start();
    final vm = actual.runtime.tasks;
    final form = TaskFormViewModel(vm);
    form.update('title', 'Clean rooftop');
    form.update('task_type', 'chore');
    form.update('assigned_to', 'ali');
    final saved = await form.submit();
    expect(saved?.kind, TaskKind.chore);
    expect(vm.draft('new'), null);
    expect(server.rows[saved!.id]!['assigned_to'], 'ali');
    final edit = TaskFormViewModel(vm, initial: saved);
    edit.update('title', 'Clean rooftop today');
    await edit.submit();
    expect(jsonDecode(server.requests.last.body)['expected_revision'], 1);
    expect(server.rows[saved.id]!['title'], 'Clean rooftop today');
    form.dispose();
    edit.dispose();
    await actual.dispose();
  });
  test('terminal status is explicit and does not call inventory', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    final completed = await vm.setStatus(
      HouseholdTask(server.rows['repair']!),
      TaskStatus.completed,
      note: 'Washer replaced',
    );
    expect(completed?.status, TaskStatus.completed);
    expect(server.inventoryWrites, 0);
    await vm.setStatus(completed!, TaskStatus.open, reopen: true);
    expect(server.rows['repair']!['status'], 'open');
    final body = jsonDecode(server.requests.last.body);
    expect(body['reopen'], true);
    expect(body['expected_revision'], 2);
    await f.dispose();
  });
  test('claims, priority, assignment and comments use revision-protected endpoints', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    var selected = HouseholdTask(server.rows['repair']!);
    selected = (await vm.assign(selected, 'claim', null))!;
    expect(selected.assignedTo, 'user-a');
    selected = (await vm.setPriority(selected, TaskPriority.high))!;
    expect(selected.priority, TaskPriority.high);
    selected = (await vm.assign(selected, 'assign', 'father'))!;
    expect(selected.assignedTo, 'father');
    final comment = await vm.addComment(selected, 'Repair is in progress');
    expect(comment?.authorId, 'user-a');
    await vm.open('repair');
    await vm.editComment(vm.task!, comment!, 'Replaced washer');
    expect(server.comments.single['body'], 'Replaced washer');
    await vm.open('repair');
    await vm.deleteComment(vm.task!, vm.comments.single);
    expect(server.comments.single['deleted_at'], isNotNull);
    await f.dispose();
  });
  test('comments and photo metadata are cached but signed URLs are never persisted', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    final selected = HouseholdTask(server.rows['repair']!);
    await vm.upload(selected, Uint8List.fromList([1, 2, 3]), commentId: null);
    await vm.open('repair');
    final attachment = vm.attachments.single;
    await vm.signPhoto(attachment);
    expect(vm.photoURL(attachment), contains('token=short'));
    expect(
      f.runtime.store.preferences
          .getKeys()
          .map((key) => f.runtime.store.preferences.get(key).toString())
          .any((value) => value.contains('token=short')),
      false,
    );
    await f.runtime.session.selectHousehold('b');
    expect(vm.photoURL(attachment), null);
    await f.dispose();
  });
  test('offline details and drafts stay scoped and failed writes are never replayed', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    vm.filters = {'as_of': '2026-11-13'};
    await vm.load();
    await vm.open('repair');
    server.offline = true;
    vm.filters = {'as_of': '2026-11-14'};
    await vm.load();
    expect(vm.listCached, true);
    expect(vm.items, isNotEmpty);
    await vm.open('repair');
    expect(vm.task?.id, 'repair');
    expect(vm.cached, true);
    final form = TaskFormViewModel(vm);
    form.update('title', 'Offline request');
    expect(await form.submit(), null);
    expect(vm.draft('new')?['title'], 'Offline request');
    final writes = server.requests.where((r) => r.method == 'POST').length;
    server.offline = false;
    await vm.load();
    expect(server.requests.where((r) => r.method == 'POST').length, writes);
    await f.runtime.session.selectHousehold('b');
    expect(vm.task, null);
    expect(vm.draft('new'), null);
    server.offline = true;
    await vm.open('repair');
    expect(vm.task, null);
    await f.runtime.session.logout();
    expect(
      f.runtime.store.preferences.getKeys().where(
        (key) => key.contains('homecircle.user.user-a.'),
      ),
      isEmpty,
    );
    form.dispose();
    await f.dispose();
  });
  test(
    'old-household actions and late responses cannot change a new household',
    () async {
      final server = TaskServer(),
          f = await fixture(server),
          pending = Completer<http.Response>();
      await f.runtime.session.start();
      final vm = f.runtime.tasks;
      server.listOverride = (_) => pending.future;
      final loading = vm.load();
      await Future<void>.delayed(Duration.zero);
      await f.runtime.session.selectHousehold('b');
      final count = server.requests.length;
      expect(await vm.assign(HouseholdTask(taskRow()), 'claim', null), null);
      expect(server.requests.length, count);
      pending.complete(
        response({
          'items': [taskRow()],
          'total': 1,
          'page': 1,
          'page_size': 20,
        }),
      );
      await loading;
      expect(vm.items, isEmpty);
      expect(
        f.runtime.store.preferences.getKeys().where(
          (key) => key.contains('.cache.tasks.'),
        ),
        isEmpty,
      );
      await f.dispose();
    },
  );
  test('comment and attachment responses cannot cross task or household boundaries', () async {
    final server = TaskServer(), f = await fixture(server);
    await f.runtime.session.start();
    final vm = f.runtime.tasks;
    final foreign = TaskComment({
      'id': 'x',
      'household_id': 'b',
      'task_id': 'repair',
      'author_user_id': 'user-a',
      'body': 'Foreign',
      'revision': 1,
    });
    final count = server.requests.length;
    expect(await vm.editComment(HouseholdTask(taskRow()), foreign, 'No'), null);
    expect(server.requests.length, count);
    await f.dispose();
  });
  testWidgets(
    'overview shows real counts, type/search filters and narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = TaskServer(), f = await fixture(server);
      await startTasks(tester, f);
      expect(find.text('Tasks & Requests'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);
      expect(find.text('1'), findsWidgets);
      await captureTask(tester, f, 'overview');
      await tapVisible(tester, find.text('Filters'));
      expect(find.text('Priority'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search tasks'),
        'missing',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(f.runtime.tasks.items, isEmpty);
      expect(
        server.requests.any(
          (r) => r.url.queryParameters['search'] == 'missing',
        ),
        true,
      );
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  testWidgets(
    'create request links a real inventory option and submits the form',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = TaskServer(), f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Create Task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Urgent tap repair',
      );
      await tapVisible(tester, find.text('Repair').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Linked inventory item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bathroom tap').last);
      await tester.pumpAndSettle();
      await captureTask(tester, f, 'form');
      await tapVisible(tester, find.text('Save request'));
      final posted = server.requests.lastWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith('/tasks'),
      );
      expect(jsonDecode(posted.body)['linked_inventory_item_id'], 'tap');
      expect(jsonDecode(posted.body)['task_type'], 'repair');
      expect(f.runtime.tasks.task?.title, 'Urgent tap repair');
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  testWidgets(
    'repair completion keeps inventory unchanged without confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = TaskServer(), f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Bathroom tap leak'));
      await captureTask(tester, f, 'details');
      await tapVisible(tester, find.text('Mark Completed'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Mark Completed').last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Would you also like to update this item's condition?"),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep Current Condition'));
      await tester.pumpAndSettle();
      expect(server.inventoryWrites, 0);
      expect(server.rows['repair']!['status'], 'completed');
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  testWidgets(
    'explicit condition update failure never undoes task completion',
    (tester) async {
      final server = TaskServer()..failInventory = true;
      final f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Bathroom tap leak'));
      await tapVisible(tester, find.text('Mark Completed'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Mark Completed').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Working'));
      await tester.pumpAndSettle();
      expect(server.inventoryWrites, 1);
      expect(server.rows['repair']!['status'], 'completed');
      expect(server.inventoryCondition, 'broken');
      expect(
        find.textContaining('The repair remains completed.'),
        findsWidgets,
      );
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  testWidgets(
    'confirmed condition update runs separately after repair completion',
    (tester) async {
      final server = TaskServer(), f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Bathroom tap leak'));
      await tapVisible(tester, find.text('Mark Completed'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Mark Completed').last,
      );
      await tester.pumpAndSettle();
      expect(server.inventoryWrites, 0);
      await tester.tap(find.text('Mark as Working'));
      await tester.pumpAndSettle();
      expect(server.inventoryWrites, 1);
      expect(server.inventoryCondition, 'working');
      expect(server.rows['repair']!['status'], 'completed');
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
  testWidgets(
    'ordinary member can assign, take ownership and discuss requests',
    (tester) async {
      final server = TaskServer(), f = await fixture(server);
      await startTasks(tester, f);
      await tapVisible(tester, find.text('Bathroom tap leak'));
      await tapVisible(tester, find.text('Change Priority'));
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['priority'], 'high');
      await tapVisible(tester, find.text('Change Status'));
      await tester.tap(find.text('In Progress').last);
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['status'], 'in_progress');
      await tapVisible(tester, find.text('Take Ownership'));
      expect(server.rows['repair']!['assigned_to'], 'user-a');
      await tapVisible(tester, find.text('Assign / Reassign'));
      await tester.tap(find.text('Father').last);
      await tester.pumpAndSettle();
      expect(server.rows['repair']!['assigned_to'], 'father');
      await tapVisible(
        tester,
        find.widgetWithText(TextField, 'Write a comment…'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Write a comment…'),
        'The replacement part is here.',
      );
      await tapVisible(tester, find.text('Send'));
      expect(server.comments.single['body'], 'The replacement part is here.');
      expect(tester.takeException(), null);
      await close(tester, f);
    },
  );
}
