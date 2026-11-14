import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_realtime_service.dart';

class FamilyChatViewModel extends ChangeNotifier {
  FamilyChatViewModel(
    this.repository,
    this.realtime,
    this.session, {
    this.refreshInterval = const Duration(seconds: 30),
  }) {
    scopeChanged();
    session.addListener(scopeChanged);
  }
  final ChatRepository repository;
  final ChatRealtimeService realtime;
  final SessionViewModel session;
  final Duration refreshInterval;
  String scope = '', draft = '', draftId = chatUuid();
  String? user, household, error, olderCursor, replyId;
  ChatMessage? replying;
  bool disposed = false,
      loading = false,
      olderLoading = false,
      hasOlder = false,
      cached = false,
      connected = false,
      cacheError = false,
      sending = false,
      syncing = false;
  int version = 0, watermark = 0;
  bool opened = false;
  int activation = -1;
  Timer? refreshTimer;
  final Map<String, ChatMessage> records = {};
  final Map<String, PendingChatMessage> pending = {};
  final Set<String> seenEvents = {};
  final Map<String, (String, DateTime)> urls = {};
  final Map<String, Map<String, dynamic>> taskPreviews = {};
  Uint8List? selectedImage;
  List<Map<String, dynamic>> taskCandidates = [];
  int taskSearchRequest = 0, taskPage = 1;
  bool taskSearchLoading = false, moreTasks = false;
  List<ChatMessage> get messages => records.values.toList()
    ..sort((a, b) {
      final stamp = a.created.compareTo(b.created);
      return stamp == 0 ? a.id.compareTo(b.id) : stamp;
    });
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
    final oldUser = user, oldHome = household;
    scope = next;
    user = session.user?.id;
    household = session.activeHousehold?.id;
    version++;
    refreshTimer?.cancel();
    unawaited(realtime.disconnect());
    records.clear();
    pending.clear();
    urls.clear();
    taskPreviews.clear();
    seenEvents.clear();
    selectedImage = null;
    taskCandidates = [];
    taskSearchRequest++;
    taskPage = 1;
    taskSearchLoading = moreTasks = false;
    draft = '';
    draftId = chatUuid();
    replyId = null;
    replying = null;
    olderCursor = null;
    watermark = 0;
    error = null;
    loading = olderLoading = hasOlder = cached = connected = cacheError =
        sending = syncing = false;
    if (oldUser != null && oldUser != user) {
      unawaited(repository.cache.clearUser(oldUser).catchError((_) {}));
    } else if (oldUser != null &&
        oldHome != null &&
        !session.restoring &&
        !session.switching &&
        !session.households.any((h) => h.id == oldHome)) {
      unawaited(
        repository.cache.clearHousehold(oldUser, oldHome).catchError((_) {}),
      );
    }
    emit();
    if (ready && opened) unawaited(activate());
  }

  Future<void> open() async {
    opened = true;
    if (!ready) return;
    if (activation == version) {
      await load();
    } else {
      await activate();
    }
  }

  Future<void> activate() async {
    if (!ready || activation == version) return;
    activation = version;
    final captured = scope, h = household!, u = user!;
    try {
      final saved = await repository.cache.read(u, h, 'history');
      if (!current(captured)) return;
      if (saved != null) {
        merge(repository.messages(saved, h));
        watermark = saved['watermark'] as int? ?? 0;
        cached = true;
      }
      final form = await repository.cache.read(u, h, 'draft');
      if (!current(captured)) return;
      draft = form?['body'] as String? ?? '';
      draftId = form?['client_message_id'] as String? ?? chatUuid();
      replyId = form?['reply_to_message_id'] as String?;
      final unsent = await repository.cache.read(u, h, 'pending');
      if (!current(captured)) return;
      for (final row in unsent?['items'] as List? ?? []) {
        final item = PendingChatMessage(
          row['client_message_id'] as String,
          row['body'] as String? ?? '',
          replyId: row['reply_to_message_id'] as String?,
          attachmentId: row['attachment_id'] as String?,
          linkedTaskId: row['linked_task_id'] as String?,
          requiresImage: row['requires_image'] == true,
        );
        item.uploaded = row['uploaded'] == true;
        item.state = ChatSendState.failed;
        item.error = 'send_failed';
        pending[item.clientId] = item;
      }
      merge(records.values.toList());
    } catch (_) {
      if (current(captured)) cacheError = true;
    }
    if (!current(captured)) return;
    emit();
    await load();
    if (!current(captured) || !opened) return;
    try {
      await realtime.connect(h, u, onEvent, (value) {
        if (current(captured)) {
          connected = value;
          emit();
          if (value) unawaited(sync());
        }
      });
    } catch (_) {
      if (current(captured)) {
        connected = false;
        emit();
      }
    }
    if (current(captured)) {
      refreshTimer = Timer.periodic(refreshInterval, (_) {
        if (current(captured)) unawaited(load());
      });
    }
  }

  void merge(Iterable<ChatMessage> incoming) {
    for (final row in incoming) {
      final previous = records[row.id];
      if (previous == null || row.version >= previous.version) {
        records[row.id] = row;
      }
      if (row.sender == user) {
        pending.remove(row.clientId);
      }
    }
    for (final child in records.values.toList()) {
      final parent = records[child.data['reply_to_message_id']];
      if (parent == null || child.deleted) continue;
      records[child.id] = ChatMessage({
        ...child.data,
        'version': child.version > parent.version
            ? child.version
            : parent.version,
        'reply_preview': {
          'id': parent.id,
          'household_id': parent.household,
          'sender_name': parent.senderName,
          'deleted': parent.deleted,
          'body': parent.deleted
              ? null
              : String.fromCharCodes(parent.body.runes.take(160)),
          'message_type': parent.type,
        },
      });
    }
  }

  Future<void> persist(String captured) async {
    if (!current(captured)) return;
    final rows = messages;
    try {
      await repository.cache.write(user!, household!, 'history', {
        'items': rows
            .skip(rows.length > 100 ? rows.length - 100 : 0)
            .map((e) => e.data)
            .toList(),
        'watermark': watermark,
      });
      await persistPending(captured);
    } catch (_) {
      if (current(captured)) {
        cacheError = true;
        emit();
      }
    }
  }

  Future<void> persistPending(String captured) async {
    if (!current(captured)) return;
    try {
      await repository.cache.write(user!, household!, 'pending', {
        'items': pending.values
            .map(
              (p) => {
                'client_message_id': p.clientId,
                'body': p.body,
                'reply_to_message_id': p.replyId,
                'linked_task_id': p.linkedTaskId,
                'requires_image': p.imageRequired,
                'attachment_id': p.attachmentId,
                'uploaded': p.uploaded,
              },
            )
            .toList(),
      });
    } catch (_) {
      if (current(captured)) {
        cacheError = true;
        emit();
      }
    }
  }

  void discardPending(PendingChatMessage item) {
    if (!ready || item.state == ChatSendState.sending) return;
    pending.remove(item.clientId);
    unawaited(
      persistPending(scope).catchError((_) {
        cacheError = true;
        emit();
      }),
    );
    emit();
  }

  Future<void> saveDraft() async {
    if (!ready) return;
    final captured = scope;
    try {
      await repository.cache.write(user!, household!, 'draft', {
        'body': draft,
        'client_message_id': draftId,
        'reply_to_message_id': replyId,
      });
    } catch (_) {
      if (current(captured)) {
        cacheError = true;
        emit();
      }
    }
  }

  void changeDraft(String body) {
    if (!ready) return;
    draft = body;
    unawaited(saveDraft());
  }

  void reply(ChatMessage? message) {
    if (!ready) return;
    replying = message;
    replyId = message?.id;
    unawaited(saveDraft());
    emit();
  }

  void photo(Uint8List? bytes) {
    if (!ready) return;
    selectedImage = bytes;
    emit();
  }

  void failure(Object e) {
    error = e is AppException ? e.code : 'unknown';
    if (e is UnauthorizedException ||
        e is ForbiddenException ||
        e is NotFoundException) {
      final u = user, h = household;
      opened = false;
      activation = -1;
      refreshTimer?.cancel();
      records.clear();
      taskPreviews.clear();
      pending.clear();
      urls.clear();
      draft = '';
      replying = null;
      replyId = null;
      selectedImage = null;
      unawaited(realtime.disconnect());
      connected = false;
      if (u != null && h != null) {
        unawaited(repository.cache.clearHousehold(u, h).catchError((_) {}));
      }
      unawaited(session.refresh());
    }
  }

  Future<void> load({bool older = false}) async {
    if (!ready || loading || (older && (olderLoading || !hasOlder))) return;
    final captured = scope,
        h = household!,
        request = version,
        initial = records.isEmpty;
    if (older) {
      olderLoading = true;
    } else {
      loading = true;
    }
    error = null;
    emit();
    try {
      final page = await repository.service.history(
        h,
        before: older ? olderCursor : null,
      );
      if (!current(captured) || request != version) return;
      merge(repository.messages(page, h));
      if (older || olderCursor == null) {
        olderCursor = page['older_cursor'] as String?;
        hasOlder = page['has_more'] as bool;
      }
      if (initial) watermark = page['watermark'] as int;
      cached = false;
      await sync();
      if (current(captured)) await persist(captured);
    } catch (e) {
      if (current(captured) && request == version) {
        cached = records.isNotEmpty;
        failure(e);
      }
    } finally {
      if (current(captured) && request == version) {
        loading = false;
        olderLoading = false;
        emit();
      }
    }
  }

  void onEvent(Map<String, dynamic> event) {
    if (!ready ||
        event['household_id'] != household ||
        event['event_id'] is! String ||
        !seenEvents.add(event['event_id'] as String)) {
      return;
    }
    if (seenEvents.length > 1000) seenEvents.remove(seenEvents.first);
    unawaited(sync());
  }

  bool syncAgain = false;
  Future<void> sync() async {
    if (!ready) return;
    if (syncing) {
      syncAgain = true;
      return;
    }
    final captured = scope, h = household!, request = version;
    syncing = true;
    try {
      do {
        syncAgain = false;
        final page = await repository.service.changes(h, watermark);
        if (!current(captured) || request != version) return;
        final after = page['after'] as int;
        if (after < watermark ||
            (page['has_more'] == true && after == watermark)) {
          throw const InvalidResponseException();
        }
        merge(repository.messages(page, h));
        watermark = after;
        cached = false;
        syncAgain = syncAgain || page['has_more'] == true;
        emit();
      } while (syncAgain && current(captured));
      await persist(captured);
    } catch (e) {
      if (current(captured) && request == version) failure(e);
    } finally {
      if (current(captured) && request == version) {
        syncing = false;
        emit();
      }
    }
  }

  Future<void> send({String? linkedTask}) async {
    if (!ready ||
        sending ||
        (draft.trim().isEmpty && selectedImage == null && linkedTask == null)) {
      return;
    }
    if (pending.length >= 20) {
      error = 'pending_limit';
      emit();
      return;
    }
    final item = PendingChatMessage(
      draftId,
      draft,
      replyId: replyId,
      image: selectedImage,
      linkedTaskId: linkedTask,
    );
    pending[item.clientId] = item;
    draft = '';
    draftId = chatUuid();
    selectedImage = null;
    replyId = null;
    replying = null;
    unawaited(saveDraft());
    emit();
    await submit(item);
  }

  Future<void> retry(PendingChatMessage item) async {
    if (!ready ||
        !pending.containsKey(item.clientId) ||
        item.state == ChatSendState.sending) {
      return;
    }
    if (item.imageRequired && !item.uploaded && item.image == null) {
      item.error = 'image_reselect';
      emit();
      return;
    }
    await submit(item);
  }

  Future<void> submit(PendingChatMessage item) async {
    final captured = scope, h = household!;
    sending = true;
    item.state = ChatSendState.sending;
    item.error = null;
    emit();
    try {
      await persistPending(captured);
      if (item.image != null && !item.uploaded) {
        item.attachmentId ??= chatUuid();
        final upload = await repository.service.upload(
          h,
          item.clientId,
          item.attachmentId!,
          item.image!,
        );
        if (!current(captured)) return;
        if (upload['id'] != item.attachmentId ||
            upload['household_id'] != h ||
            upload['client_message_id'] != item.clientId) {
          throw const InvalidResponseException();
        }
        item.uploaded = true;
        await persistPending(captured);
      }
      final row = repository.message(
        await repository.service.send(h, item.payload),
        h,
      );
      if (!current(captured)) return;
      if (row.clientId != item.clientId || row.sender != user) {
        throw const InvalidResponseException();
      }
      item.state = ChatSendState.sent;
      merge([row]);
      await persist(captured);
      await sync();
    } catch (e) {
      if (current(captured)) {
        item.state = ChatSendState.failed;
        item.error = e is AppException ? e.code : 'unknown';
        if (item.imageRequired &&
            e is AppException &&
            e.code == 'invalid_attachment') {
          // The server checked idempotency first: this rejection confirms that
          // the old permit was not committed into a message.
          item.uploaded = false;
        }
        if (!item.uploaded) item.attachmentId = null;
        try {
          await persistPending(captured);
        } catch (_) {
          cacheError = true;
        }
        if (e is UnauthorizedException || e is ForbiddenException) failure(e);
      }
    } finally {
      if (current(captured)) {
        sending = false;
        emit();
      }
    }
  }

  Future<void> edit(ChatMessage item, String body) async => mutate(
    item,
    (h) => repository.service.edit(h, item.id, item.revision, body),
  );
  Future<void> delete(ChatMessage item) async =>
      mutate(item, (h) => repository.service.delete(h, item.id, item.revision));
  Future<void> react(ChatMessage item, String emoji, bool remove) async =>
      mutate(item, (h) => repository.service.react(h, item.id, emoji, remove));
  Future<void> mutate(
    ChatMessage item,
    Future<Map<String, dynamic>> Function(String) action,
  ) async {
    if (!ready || item.household != household) return;
    final captured = scope, h = household!;
    error = null;
    try {
      final row = repository.message(await action(h), h);
      if (current(captured)) {
        if (row.id != item.id) throw const InvalidResponseException();
        merge([row]);
        await persist(captured);
        emit();
      }
    } catch (e) {
      if (current(captured)) {
        failure(e);
        if (e is AppException && e.code == 'revision_conflict') {
          await sync();
          error = e.code;
        }
        emit();
      }
    }
  }

  String? imageUrl(String id) {
    final value = urls[id];
    return value == null || DateTime.now().isAfter(value.$2) ? null : value.$1;
  }

  Future<void> loadImage(
    ChatMessage item,
    Map<String, dynamic> attachment,
  ) async {
    if (!ready ||
        item.household != household ||
        item.deleted ||
        attachment['household_id'] != household ||
        attachment['message_id'] != item.id) {
      return;
    }
    final captured = scope;
    try {
      final result = await repository.service.imageUrl(
        household!,
        attachment['id'] as String,
      );
      if (current(captured) && records[item.id]?.deleted != true) {
        urls[attachment['id'] as String] = (
          result['url'] as String,
          DateTime.now().add(Duration(seconds: result['expires_in'] as int)),
        );
        emit();
      }
    } catch (e) {
      if (current(captured)) {
        error = e is AppException ? e.code : 'unknown';
        emit();
      }
    }
  }

  Future<void> refreshTaskPreview(String id) async {
    if (!ready) return;
    final captured = scope, h = household!;
    try {
      final row = await repository.service.task(h, id);
      if (!current(captured)) return;
      if (row['id'] != id || row['household_id'] != h) {
        throw const InvalidResponseException();
      }
      taskPreviews[id] = row['deleted_at'] == null
          ? row
          : {'id': id, 'household_id': h, 'unavailable': true};
      emit();
    } on NotFoundException {
      if (current(captured)) {
        taskPreviews[id] = {'id': id, 'household_id': h, 'unavailable': true};
        emit();
      }
    } catch (e) {
      if (current(captured)) {
        failure(e);
        emit();
      }
    }
  }

  Future<void> findTasks(String search, {bool more = false}) async {
    if (!ready || (more && taskSearchLoading)) return;
    final captured = scope,
        request = ++taskSearchRequest,
        page = more ? taskPage + 1 : 1,
        h = household!;
    taskSearchLoading = true;
    error = null;
    if (!more) taskCandidates = [];
    emit();
    try {
      final data = await repository.service.tasks(h, search, page);
      if (!current(captured) || request != taskSearchRequest) return;
      final rows = (data['items'] as List).cast<Map<String, dynamic>>();
      if (rows.any((row) => row['household_id'] != h)) {
        throw const InvalidResponseException();
      }
      taskCandidates = more ? [...taskCandidates, ...rows] : rows;
      taskPage = page;
      moreTasks = taskCandidates.length < (data['total'] as int);
    } catch (e) {
      if (current(captured) && request == taskSearchRequest) failure(e);
    } finally {
      if (current(captured) && request == taskSearchRequest) {
        taskSearchLoading = false;
        emit();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    version++;
    refreshTimer?.cancel();
    session.removeListener(scopeChanged);
    unawaited(realtime.disconnect());
    records.clear();
    pending.clear();
    urls.clear();
    selectedImage = null;
    taskPreviews.clear();
    super.dispose();
  }
}
