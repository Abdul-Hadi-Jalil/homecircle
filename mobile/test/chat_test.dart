import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/chat/models/chat_message.dart';
import 'package:homecircle/features/chat/models/chat_task_source.dart';
import 'package:homecircle/features/chat/services/chat_realtime_service.dart';
import 'package:homecircle/features/chat/repositories/chat_cache.dart';
import 'package:homecircle/features/tasks/viewmodels/task_form_view_model.dart';
import 'package:homecircle/features/shopping/viewmodels/shopping_form_viewmodel.dart';

import 'support/fakes.dart';
import 'tasks_test.dart'
    show taskRow, response, startTasks, tapVisible, captureTask;
import 'shopping_test.dart' show ShoppingServer, shoppingRow;

class FakeChatRealtime implements ChatRealtimeService {
  void Function(Map<String, dynamic>)? event;
  void Function(bool)? status;
  String? household, user;
  int disconnects = 0;
  @override
  Future<void> connect(
    String h,
    String u,
    void Function(Map<String, dynamic>) onEvent,
    void Function(bool) onState,
  ) async {
    household = h;
    user = u;
    event = onEvent;
    status = onState;
    onState(true);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    event = null;
    status = null;
    household = null;
  }

  void emit(Map<String, dynamic> data) => event?.call(data);
}

class ChatServer extends ShoppingServer {
  final messages = <String, Map<String, dynamic>>{};
  final changes = <Map<String, dynamic>>[];
  final conversions = <String, Map<String, dynamic>>{};
  int sequence = 0;
  bool loseAcknowledgement = false, deny = false;
  Completer<void>? holdSend;
  Future<http.Response> Function(http.Request)? chatOverride;
  ChatServer() {
    add('Bring milk', sender: 'mother');
  }
  Map<String, dynamic> add(
    String body, {
    String home = 'a',
    String sender = 'user-a',
    String? clientId,
    String? reply,
    String type = 'text',
    String? linkedTask,
  }) {
    final id = 'message-${messages.length + 1}';
    final row = <String, dynamic>{
      'id': id,
      'household_id': home,
      'sender_user_id': sender,
      'sender_name': sender == 'user-a' ? 'Arham' : 'Mother',
      'client_message_id': clientId ?? chatUuid(),
      'message_type': type,
      'body': body,
      'reply_to_message_id': reply,
      'reply_preview': null,
      'linked_task_id': linkedTask,
      'task': linkedTask == null ? null : rows[linkedTask],
      'converted_tasks': <Map<String, dynamic>>[],
      'attachments': <Map<String, dynamic>>[],
      'reactions': <Map<String, dynamic>>[],
      'created_at': DateTime.utc(
        2026,
        11,
        14,
        9,
      ).add(Duration(seconds: messages.length)).toIso8601String(),
      'updated_at': null,
      'edited_at': null,
      'deleted_at': null,
      'revision': 1,
      'version': 0,
    };
    if (reply != null) {
      final parent = messages[reply]!;
      row['reply_preview'] = {
        'id': reply,
        'household_id': home,
        'sender_name': parent['sender_name'],
        'body': parent['body'],
        'deleted': parent['deleted_at'] != null,
        'message_type': parent['message_type'],
      };
    }
    messages[id] = row;
    event(row);
    return row;
  }

  Map<String, dynamic> event(Map<String, dynamic> row) {
    row['version'] = ++sequence;
    final entry = {
      'sequence': sequence,
      'household_id': row['household_id'],
      'message_id': row['id'],
      'event_id': 'event-$sequence',
    };
    changes.add(entry);
    return entry;
  }

  Map<String, dynamic> visible(Map<String, dynamic> row) {
    final value = jsonDecode(jsonEncode(row)) as Map<String, dynamic>;
    if (row['deleted_at'] != null) {
      value.addAll({
        'body': null,
        'reply_preview': null,
        'reply_to_message_id': null,
        'linked_task_id': null,
        'task': null,
        'reactions': [],
        'attachments': [],
        'converted_tasks': [],
      });
    }
    return value;
  }

  @override
  Future<http.Response> call(http.Request request) async {
    if (!request.url.path.contains('/chat/')) return super.call(request);
    requests.add(request);
    if (offline) throw http.ClientException('Offline');
    if (deny) {
      return response({
        'error': {'code': 'forbidden'},
      }, 403);
    }
    if (chatOverride != null) return chatOverride!(request);
    final s = request.url.pathSegments,
        h = s[3],
        query = request.url.queryParameters;
    if (s.last == 'changes') {
      final after = int.parse(query['after'] ?? '0');
      final events = changes
          .where(
            (e) => e['household_id'] == h && (e['sequence'] as int) > after,
          )
          .toList();
      return response({
        'items': events
            .map((e) => e['message_id'])
            .toSet()
            .map((id) => visible(messages[id]!))
            .toList(),
        'after': events.isEmpty ? after : events.last['sequence'],
        'has_more': false,
      });
    }
    if (s.last == 'messages' && request.method == 'GET') {
      var rows = messages.values.where((m) => m['household_id'] == h).toList();
      if (query['before'] != null) {
        final index = rows.indexWhere((m) => m['id'] == query['before']);
        rows = rows.take(index < 0 ? 0 : index).toList();
      }
      final more = rows.length > 30;
      if (more) rows = rows.sublist(rows.length - 30);
      final mark =
          changes
              .where((e) => e['household_id'] == h)
              .lastOrNull?['sequence'] ??
          0;
      return response({
        'items': rows.map(visible).toList(),
        'has_more': more,
        'older_cursor': rows.firstOrNull?['id'],
        'watermark': mark,
      });
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (s.last == 'attachments') {
      return response({
        'id': body['attachment_id'],
        'household_id': h,
        'client_message_id': body['client_message_id'],
        'content_type': 'image/jpeg',
        'size_bytes': 3,
      }, 201);
    }
    if (s.last == 'url') {
      return response({
        'url': 'https://example.test/private.jpg?token=short',
        'expires_in': 60,
      });
    }
    if (s.last == 'messages' && request.method == 'POST') {
      await holdSend?.future;
      final prior = messages.values
          .where(
            (m) =>
                m['household_id'] == h &&
                m['client_message_id'] == body['client_message_id'],
          )
          .firstOrNull;
      if (prior != null) return response(visible(prior));
      final row = add(
        body['body'] as String? ?? '',
        home: h,
        clientId: body['client_message_id'] as String,
        reply: body['reply_to_message_id'] as String?,
        type: body['message_type'] as String,
        linkedTask: body['linked_task_id'] as String?,
      );
      for (final id in body['attachment_ids'] as List? ?? []) {
        (row['attachments'] as List).add({
          'id': id,
          'household_id': h,
          'message_id': row['id'],
          'uploaded_by': 'user-a',
          'content_type': 'image/jpeg',
          'size_bytes': 3,
        });
      }
      if (loseAcknowledgement) {
        loseAcknowledgement = false;
        throw http.ClientException('Response lost after persistence');
      }
      return response(visible(row), 201);
    }
    final row = messages[s[6]];
    if (row == null || row['household_id'] != h) {
      return response({
        'error': {'code': 'not_found'},
      }, 404);
    }
    if (s.last == 'create-task') {
      final key = body['client_request_id'] as String;
      if (conversions[key] != null) return response(conversions[key]);
      final fields = body['fields'] as Map<String, dynamic>,
          type = body['task_type'] as String,
          id = 'converted-${conversions.length + 1}';
      final task = type == 'shopping'
          ? (shoppingRow(id: id, home: h)
              ..addAll(fields)
              ..['priority'] = fields['priority'] ?? 'normal')
          : (taskRow(
              id: id,
              home: h,
              type: type,
              title: fields['title'] as String,
            )..addAll(fields));
      if (type == 'shopping') {
        shopping[id] = task;
      } else {
        rows[id] = task;
      }
      conversions[key] = task;
      (row['converted_tasks'] as List).add(task);
      event(row);
      return response(task, 201);
    }
    if (s.contains('reactions')) {
      final emoji = request.method == 'DELETE' ? s.last : body['emoji'];
      final reactions = row['reactions'] as List;
      reactions.removeWhere((r) => r['emoji'] == emoji);
      if (request.method != 'DELETE') {
        reactions.add({'emoji': emoji, 'count': 1, 'mine': true});
      }
      event(row);
      return response(visible(row));
    }
    final expected =
        body['expected_revision'] ??
        int.tryParse(query['expected_revision'] ?? '');
    if (expected != row['revision']) {
      return response({
        'error': {'code': 'revision_conflict'},
      }, 409);
    }
    if (request.method == 'DELETE') {
      row['deleted_at'] = '2026-11-14T10:00:00Z';
    } else {
      row['body'] = body['body'];
      row['edited_at'] = '2026-11-14T10:00:00Z';
    }
    row['revision'] = (row['revision'] as int) + 1;
    event(row);
    return response(visible(row));
  }
}

Future<(TestRuntime, FakeChatRealtime)> chatFixture(
  ChatServer server, {
  MemoryChatCache? cache,
}) async {
  final live = FakeChatRealtime();
  final f = await createTestRuntime(
    identity: const AuthIdentity(id: 'user-a'),
    preferences: {'homecircle.user.user-a.active': 'a'},
    respond: server.call,
    chatCache: cache,
    chatRealtime: live,
  );
  await f.runtime.session.start();
  return (f, live);
}

Future<void> startChat(WidgetTester tester, TestRuntime f) async {
  await startTasks(tester, f);
  await tester.tap(find.text('Chat').last);
  await tester.pumpAndSettle();
}

Future<void> closeChat(WidgetTester tester, TestRuntime f) async {
  await tester.pumpWidget(const SizedBox());
  await f.auth.events.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('secure cache isolates households and serializes writes before logout cleanup', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final cache = SecureChatCache(const FlutterSecureStorage());
    await cache.write('first', 'a', 'draft', {'body': 'House A'});
    await cache.write('first', 'b', 'draft', {'body': 'House B'});
    await cache.write('second', 'a', 'draft', {'body': 'Another account'});
    await cache.clearHousehold('first', 'a');
    expect(await cache.read('first', 'a', 'draft'), null);
    expect((await cache.read('first', 'b', 'draft'))?['body'], 'House B');
    final writing = cache.write('first', 'b', 'history', {'items': []});
    final clearing = cache.clearUser('first');
    await Future.wait([writing, clearing]);
    expect(await cache.read('first', 'b', 'history'), null);
    expect(
      (await cache.read('second', 'a', 'draft'))?['body'],
      'Another account',
    );
  });
  test('foreign reply metadata is rejected even without attachments', () async {
    final server = ChatServer(), pair = await chatFixture(server), f = pair.$1;
    final row = server.add('Invalid reply', reply: server.messages.keys.first);
    (row['reply_preview'] as Map)['household_id'] = 'b';
    await f.runtime.chat.open();
    expect(f.runtime.chat.messages, isEmpty);
    expect(f.runtime.chat.error, 'invalid_response');
    await f.dispose();
  });
  test(
    'authorization failure clears chat and stops the private channel',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1;
      final vm = f.runtime.chat;
      await vm.open();
      vm.changeDraft('Private unsent');
      await vm.saveDraft();
      server.deny = true;
      await vm.load();
      await Future<void>.delayed(Duration.zero);
      expect(vm.messages, isEmpty);
      expect(vm.draft, isEmpty);
      expect(vm.urls, isEmpty);
      expect(pair.$2.household, null);
      await f.dispose();
    },
  );
  test(
    'task sharing resolves current status and sends a real task reference',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1;
      final vm = f.runtime.chat;
      await vm.open();
      await vm.findTasks('');
      final task = vm.taskCandidates.first;
      await vm.refreshTaskPreview(task['id'] as String);
      expect(vm.taskPreviews[task['id']]?['household_id'], 'a');
      await vm.send(linkedTask: task['id'] as String);
      expect(vm.messages.last.type, 'task_share');
      expect(vm.messages.last.data['linked_task_id'], task['id']);
      await f.dispose();
    },
  );
  test('message serialization uses stable UUIDs and hides deleted body', () {
    final server = ChatServer(), row = server.messages.values.first;
    final message = ChatMessage(row);
    expect(message.body, 'Bring milk');
    expect(message.sender, 'mother');
    expect(
      chatUuid(),
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
    expect(ChatMessage({...row, 'deleted_at': 'now'}).body, '');
  });
  test('send failure retries the same client UUID and deduplicates persisted result', () async {
    final server = ChatServer(),
        pair = await chatFixture(server),
        f = pair.$1,
        vm = f.runtime.chat;
    await vm.open();
    server.loseAcknowledgement = true;
    vm.changeDraft('Hello family');
    await vm.send();
    expect(vm.pending.values.single.state, ChatSendState.failed);
    final pending = vm.pending.values.single;
    await vm.retry(pending);
    expect(vm.pending, isEmpty);
    expect(vm.messages.where((m) => m.body == 'Hello family'), hasLength(1));
    final requests = server.requests
        .where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/chat/messages'),
        )
        .map((r) => jsonDecode(r.body)['client_message_id'])
        .toList();
    expect(requests, hasLength(2));
    expect(requests[0], requests[1]);
    await f.dispose();
  });
  test(
    'duplicate and out of order realtime events refresh authoritative messages',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1,
          live = pair.$2,
          vm = f.runtime.chat;
      await vm.open();
      final row = server.add('Realtime incoming', sender: 'mother'),
          event = server.changes.last;
      live.emit(event);
      live.emit(event);
      live.emit(server.changes.first);
      await vm.sync();
      await Future<void>.delayed(Duration.zero);
      expect(vm.messages.where((m) => m.id == row['id']), hasLength(1));
      expect(vm.messages.last.body, 'Realtime incoming');
      final old = vm.messages.last;
      await vm.react(old, '👍', false);
      expect(vm.records[old.id]!.reactions.single['count'], 1);
      await vm.react(vm.records[old.id]!, '👍', true);
      expect(vm.records[old.id]!.reactions, isEmpty);
      await f.dispose();
    },
  );
  test(
    'pagination retains older history and cache stores no signed URLs',
    () async {
      final server = ChatServer();
      for (var i = 0; i < 65; i++) {
        server.add('History $i');
      }
      final pair = await chatFixture(server), f = pair.$1, vm = f.runtime.chat;
      await vm.open();
      expect(vm.messages, hasLength(30));
      await vm.load(older: true);
      expect(vm.messages, hasLength(60));
      await vm.load(older: true);
      expect(vm.messages, hasLength(66));
      expect(vm.hasOlder, false);
      final cache = f.runtime.chat.repository.cache as MemoryChatCache;
      expect(jsonEncode(cache.values), isNot(contains('token=short')));
      expect(
        f.runtime.store.preferences.getKeys().any(
          (key) => key.contains('chat'),
        ),
        false,
      );
      await f.dispose();
    },
  );
  test(
    'offline drafts and pending UUIDs survive restart without automatic send',
    () async {
      final server = ChatServer(),
          cache = MemoryChatCache(),
          pair = await chatFixture(server, cache: cache),
          f = pair.$1,
          vm = f.runtime.chat;
      await vm.open();
      server.offline = true;
      vm.changeDraft('Offline message');
      await vm.send();
      final id = vm.pending.values.single.clientId;
      await vm.saveDraft();
      await f.dispose();
      final second = (await chatFixture(server, cache: cache)).$1;
      await second.runtime.chat.open();
      expect(second.runtime.chat.pending[id]?.state, ChatSendState.failed);
      final posts = server.requests
          .where(
            (r) => r.method == 'POST' && r.url.path.contains('/chat/messages'),
          )
          .length;
      server.offline = false;
      await second.runtime.chat.load();
      expect(
        server.requests
            .where(
              (r) =>
                  r.method == 'POST' && r.url.path.contains('/chat/messages'),
            )
            .length,
        posts,
      );
      await second.runtime.chat.retry(second.runtime.chat.pending[id]!);
      expect(
        second.runtime.chat.messages.any((m) => m.body == 'Offline message'),
        true,
      );
      await second.dispose();
    },
  );
  test(
    'household switch rejects late callbacks and logout clears secure chat',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1,
          live = pair.$2,
          vm = f.runtime.chat;
      await vm.open();
      final callback = live.event!;
      vm.changeDraft('Private household A');
      await vm.saveDraft();
      await f.runtime.session.selectHousehold('b');
      await vm.open();
      callback({'household_id': 'a', 'event_id': 'late'});
      await Future<void>.delayed(Duration.zero);
      expect(vm.messages, isEmpty);
      expect(vm.draft, '');
      expect(live.household, 'b');
      await f.runtime.session.logout();
      await Future<void>.delayed(Duration.zero);
      expect((vm.repository.cache as MemoryChatCache).values, isEmpty);
      expect(live.household, null);
      await f.dispose();
    },
  );
  test('parent deletion removes text from cached reply previews', () async {
    final server = ChatServer(),
        pair = await chatFixture(server),
        f = pair.$1,
        vm = f.runtime.chat;
    final parent = server.add('Private parent'),
        reply = server.add('Reply', reply: parent['id'] as String);
    await vm.open();
    await vm.delete(vm.records[parent['id']]!);
    expect(vm.records[reply['id']]!.reply!['deleted'], true);
    expect(vm.records[reply['id']]!.reply!['body'], null);
    await f.dispose();
  });
  test('message-to-request forms use existing services and encrypted source drafts', () async {
    final server = ChatServer(), pair = await chatFixture(server), f = pair.$1;
    await f.runtime.chat.open();
    final message = f.runtime.chat.messages.first;
    final source = ChatTaskSource(
      messageId: message.id,
      household: 'a',
      body: message.body,
      revision: message.revision,
    );
    final task = TaskFormViewModel(
      f.runtime.tasks,
      initialType: 'repair',
      chatSource: source,
      chatCache: f.runtime.chat.repository.cache,
    );
    task.update('title', 'Repair from chat');
    await task.persistDraft();
    expect(
      f.runtime.store.preferences.getKeys().any((key) => key.contains('chat')),
      false,
    );
    expect(
      (await f.runtime.chat.repository.cache.read(
        'user-a',
        'a',
        task.draftKey,
      ))?['description'],
      'Bring milk',
    );
    final saved = await task.submit();
    expect(saved?.kind.name, 'repair');
    expect(server.conversions, hasLength(1));
    final shopping = ShoppingFormViewModel(
      f.runtime.shopping,
      chatSource: ChatTaskSource(
        messageId: message.id,
        household: 'a',
        body: message.body,
        revision: message.revision,
      ),
      chatCache: f.runtime.chat.repository.cache,
    );
    shopping.update('title', 'Milk from chat');
    final bought = await shopping.submit();
    expect(bought?.kind.name, 'shopping');
    expect(server.conversions, hasLength(2));
    expect(
      f.runtime.store.preferences
          .getKeys()
          .map((key) => f.runtime.store.preferences.get(key))
          .join(),
      isNot(contains('_chat_message_id')),
    );
    task.dispose();
    shopping.dispose();
    await f.dispose();
  });
  test(
    'image upload is finalized before message send and URL stays in memory',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1,
          vm = f.runtime.chat;
      await vm.open();
      vm.photo(Uint8List.fromList([1, 2, 3]));
      await vm.send();
      final message = vm.messages.last;
      expect(message.type, 'image');
      expect(message.attachments, hasLength(1));
      final calls = server.requests
          .where((r) => r.method == 'POST' && r.url.path.contains('/chat/'))
          .toList();
      expect(calls[calls.length - 2].url.path, endsWith('/attachments'));
      expect(calls.last.url.path, endsWith('/messages'));
      await vm.loadImage(message, message.attachments.single);
      expect(
        vm.imageUrl(message.attachments.single['id'] as String),
        contains('token=short'),
      );
      expect(
        jsonEncode((vm.repository.cache as MemoryChatCache).values),
        isNot(contains('token=short')),
      );
      await f.dispose();
    },
  );
  test(
    'expired image permit can be reuploaded with the original message UUID',
    () async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1,
          vm = f.runtime.chat;
      await vm.open();
      server.chatOverride = (request) async {
        if (request.url.path.endsWith('/attachments')) {
          final body = jsonDecode(request.body) as Map;
          return response({
            'id': body['attachment_id'],
            'household_id': 'a',
            'client_message_id': body['client_message_id'],
          }, 201);
        }
        return response({
          'error': {'code': 'invalid_attachment', 'message': 'Expired permit'},
        }, 422);
      };
      vm.photo(Uint8List.fromList([1, 2, 3]));
      await vm.send();
      final pending = vm.pending.values.single, original = pending.clientId;
      expect(pending.uploaded, false);
      expect(pending.attachmentId, null);
      server.chatOverride = null;
      await vm.retry(pending);
      expect(vm.pending, isEmpty);
      expect(vm.messages.last.clientId, original);
      expect(vm.messages.last.type, 'image');
      await f.dispose();
    },
  );
  testWidgets('empty chat and sending state use the real composer flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = ChatServer()
          ..messages.clear()
          ..changes.clear(),
        pair = await chatFixture(server),
        f = pair.$1;
    await startChat(tester, f);
    expect(
      find.textContaining('Start your household conversation'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Message your family…'),
      'Hello',
    );
    server.holdSend = Completer<void>();
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sending…'), findsOneWidget);
    server.holdSend!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.textContaining('Sent'), findsWidgets);
    expect(tester.takeException(), null);
    await closeChat(tester, f);
  });
  testWidgets(
    'replies reactions ownership menus and edit/delete render correctly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1;
      await startChat(tester, f);
      await tester.longPress(find.text('Bring milk'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Message'), findsNothing);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.reply), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextField, 'Message your family…'),
        'I can get it',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await captureTask(tester, f, 'chat');
      await tester.longPress(find.text('I can get it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('👍').first);
      await tester.pumpAndSettle();
      expect(find.text('👍 1'), findsOneWidget);
      await tester.longPress(find.text('I can get it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Message'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'On my way');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('On my way'), findsOneWidget);
      await tester.longPress(find.text('On my way'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('This message was deleted.'), findsOneWidget);
      expect(tester.takeException(), null);
      await closeChat(tester, f);
    },
  );
  testWidgets(
    'reviewed message creates one shopping request through existing form',
    (tester) async {
      final server = ChatServer(),
          pair = await chatFixture(server),
          f = pair.$1;
      await startChat(tester, f);
      await tester.longPress(find.text('Bring milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Task from Message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Bring milk'), findsWidgets);
      await tapVisible(tester, find.text('Add to List'));
      expect(server.conversions, hasLength(1));
      expect(
        server.shopping.values.any((r) => r['title'] == 'Bring milk'),
        true,
      );
      expect(tester.takeException(), null);
      await closeChat(tester, f);
    },
  );
}
