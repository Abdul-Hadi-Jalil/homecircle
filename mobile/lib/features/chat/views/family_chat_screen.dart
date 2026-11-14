import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../../tasks/widgets/task_photo_picker.dart';
import '../models/chat_message.dart';
import '../models/chat_task_source.dart';
import '../viewmodels/family_chat_viewmodel.dart';

const chatEmoji = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({super.key});
  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen>
    with WidgetsBindingObserver {
  final composer = TextEditingController(), scroll = ScrollController();
  FamilyChatViewModel? model;
  String? lastMessage;
  int unseen = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      model = context.read<FamilyChatViewModel>();
      model!.addListener(changed);
      model!.open();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model?.load();
  }

  void changed() {
    if (!mounted) return;
    final vm = model!;
    if (composer.text != vm.draft) {
      composer.value = TextEditingValue(
        text: vm.draft,
        selection: TextSelection.collapsed(offset: vm.draft.length),
      );
    }
    final last = vm.messages.lastOrNull?.id;
    if (last != null && last != lastMessage) {
      final near =
          !scroll.hasClients ||
          scroll.position.maxScrollExtent - scroll.offset < 120;
      if (near || lastMessage == null) {
        bottom();
      } else {
        setState(() => unseen++);
      }
      lastMessage = last;
    }
  }

  void bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        if (unseen != 0) setState(() => unseen = 0);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model?.removeListener(changed);
    composer.dispose();
    scroll.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  Future<void> older() async {
    final offset = scroll.hasClients ? scroll.offset : 0.0,
        extent = scroll.hasClients ? scroll.position.maxScrollExtent : 0.0;
    await model!.load(older: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(
          (offset + scroll.position.maxScrollExtent - extent).clamp(
            0,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  Future<void> chooseImage() async {
    try {
      final bytes = await pickTaskPhoto();
      if (bytes != null && mounted) model!.photo(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.taskCopy.taskPhotoLimit)),
        );
      }
    }
  }

  Future<void> convert(ChatMessage message) async {
    final vm = model!, captured = model!.scope, l = context.taskCopy;
    final type = await showModalBottomSheet<TaskKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.chatCreateTask,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final kind in TaskKind.values)
              ListTile(
                leading: Icon(taskKindIcon(kind)),
                title: Text(taskLabel(context, kind.name)),
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
    if (!mounted || !vm.current(captured) || type == null) return;
    final source = ChatTaskSource(
      messageId: message.id,
      household: message.household,
      body: message.body,
      revision: message.revision,
    );
    await context.pushNamed(
      type == TaskKind.shopping ? 'addShopping' : 'createTask',
      queryParameters: type == TaskKind.shopping ? {} : {'type': type.name},
      extra: source,
    );
    if (mounted && vm.current(captured)) await vm.load();
  }

  Future<void> actions(ChatMessage message) async {
    if (message.deleted) return;
    final l = context.taskCopy, vm = model!, captured = model!.scope;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 4,
                children: [
                  for (final emoji in chatEmoji)
                    IconButton(
                      tooltip: emoji,
                      onPressed: () => Navigator.pop(context, 'react:$emoji'),
                      icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l.chatReply),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
              if (message.body.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(l.chatCopy),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
              ListTile(
                leading: const Icon(Icons.add_task),
                title: Text(l.chatCreateTask),
                onTap: () => Navigator.pop(context, 'task'),
              ),
              if (message.sender == vm.user) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.chatEdit),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l.chatDelete),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || !vm.current(captured) || action == null) return;
    if (action == 'reply') {
      vm.reply(message);
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.body));
      return;
    }
    if (action == 'task') {
      await convert(message);
      return;
    }
    if (action.startsWith('react:')) {
      final emoji = action.substring(6);
      final mine = message.reactions.any(
        (e) => e['emoji'] == emoji && e['mine'] == true,
      );
      await vm.react(message, emoji, mine);
      return;
    }
    if (action == 'delete') {
      if (await confirmTask(context, l.chatDelete, message: l.chatDeleteHelp) &&
          mounted &&
          vm.current(captured)) {
        await vm.delete(message);
      }
      return;
    }
    if (action == 'edit') {
      final body = await showDialog<String>(
        context: context,
        builder: (_) => _ChatEditDialog(message.body),
      );
      if (body != null && mounted && vm.current(captured)) {
        await vm.edit(message, body);
      }
    }
  }

  Future<void> shareTask() async {
    final vm = model!, captured = model!.scope, l = context.taskCopy;
    final task = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChatTaskPicker(),
    );
    if (task == null || !mounted || !vm.current(captured)) return;
    if (await confirmTask(
          context,
          l.chatShareTask,
          message: task['title'] as String,
        ) &&
        mounted &&
        vm.current(captured)) {
      await vm.send(linkedTask: task['id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FamilyChatViewModel>(),
        l = context.taskCopy,
        home = vm.session.activeHousehold,
        rows = vm.messages;
    return AppScaffold(
      title: l.chatTitle,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.loading ? null : () => vm.load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (home?.name.isNotEmpty == true ? home!.name : '?')
                    .characters
                    .first,
              ),
            ),
            title: Text(
              home?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(l.chatMembers(home?.memberCount ?? 0)),
            trailing: IconButton(
              tooltip: l.familyMembers,
              onPressed: () => context.pushNamed('members'),
              icon: const Icon(Icons.info_outline),
            ),
          ),
          if (!vm.connected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                l.chatReconnecting,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (vm.cached)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l.chatCached),
            ),
          if (vm.cacheError)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l.chatCacheError),
            ),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(chatError(context, vm.error)),
            ),
          if (vm.loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (vm.hasOlder)
                  TextButton(
                    onPressed: vm.olderLoading ? null : older,
                    child: Text(l.chatOlder),
                  ),
                if (vm.olderLoading) const LinearProgressIndicator(),
                if (rows.isEmpty && vm.pending.isEmpty && !vm.loading)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(l.chatEmpty, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i == 0 ||
                      DateUtils.dateOnly(rows[i - 1].created.toLocal()) !=
                          DateUtils.dateOnly(rows[i].created.toLocal()))
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Chip(
                          label: Text(
                            DateFormat.yMMMd().format(
                              rows[i].created.toLocal(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  _ChatBubble(
                    message: rows[i],
                    mine: rows[i].sender == vm.user,
                    onLongPress: () => actions(rows[i]),
                  ),
                ],
                for (final pending in vm.pending.values)
                  _PendingBubble(item: pending),
              ],
            ),
          ),
          if (unseen > 0)
            TextButton.icon(
              onPressed: bottom,
              icon: const Icon(Icons.arrow_downward),
              label: Text(l.chatNewMessages(unseen)),
            ),
          Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.replyId != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.reply),
                        title: Text(vm.replying?.senderName ?? l.chatReply),
                        subtitle: Text(
                          vm.replying?.body ?? l.chatReplyUnavailable,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: l.taskDismiss,
                          onPressed: () => vm.reply(null),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    if (vm.selectedImage != null)
                      Row(
                        children: [
                          Image.memory(
                            vm.selectedImage!,
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                          IconButton(
                            tooltip: l.taskRemovePhoto,
                            onPressed: () => vm.photo(null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: l.chatAttach,
                          onPressed: vm.sending ? null : chooseImage,
                          icon: const Icon(Icons.photo_camera_outlined),
                        ),
                        IconButton(
                          tooltip: l.chatShareTask,
                          onPressed: vm.sending ? null : shareTask,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: composer,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 4000,
                            onChanged: (body) {
                              vm.changeDraft(body);
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: l.chatComposer,
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: l.chatSend,
                          onPressed:
                              !vm.ready ||
                                  vm.sending ||
                                  (composer.text.trim().isEmpty &&
                                      vm.selectedImage == null)
                              ? null
                              : () {
                                  vm.send();
                                  bottom();
                                },
                          icon: const Icon(Icons.send_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String chatError(BuildContext context, String? code) {
  final l = context.taskCopy;
  return switch (code) {
    'network' => l.chatOffline,
    'forbidden' || 'unauthorized' || 'not_found' => l.chatAccessRevoked,
    'revision_conflict' => l.chatConflict,
    'rate_limited' => l.chatRateLimited,
    'idempotency_conflict' => l.chatRetryOriginal,
    'message_deleted' => l.chatDeleted,
    'invalid_photo' || 'photo_too_large' => l.taskPhotoLimit,
    'pending_limit' => l.chatPendingLimit,
    'image_reselect' || 'upload_failed' => l.chatReselectImage,
    _ => l.chatFailure,
  };
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.mine,
    required this.onLongPress,
  });
  final ChatMessage message;
  final bool mine;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .82,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          (message.senderName?.isNotEmpty == true
                                  ? message.senderName!
                                  : '?')
                              .characters
                              .first,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.senderName ?? l.taskFormerMember,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Material(
                color: mine ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onLongPress: message.deleted ? null : onLongPress,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.reply != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Colors.white.withValues(alpha: .15)
                                  : AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              message.reply!['deleted'] == true
                                  ? l.chatReplyUnavailable
                                  : '${message.reply!['sender_name'] ?? l.taskFormerMember}\n${message.reply!['body'] ?? ''}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mine ? Colors.white : AppColors.text,
                              ),
                            ),
                          ),
                        if (message.deleted || message.body.isNotEmpty)
                          Text(
                            message.deleted ? l.chatDeleted : message.body,
                            style: TextStyle(
                              color: mine ? Colors.white : AppColors.text,
                              fontSize: 16,
                              fontStyle: message.deleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        for (final attachment in message.attachments)
                          _ChatImage(message: message, attachment: attachment),
                        for (final task in message.tasks) _SharedTask(task),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${DateFormat.jm().format(message.created.toLocal())}${message.edited ? ' · ${l.chatEdited}' : ''}${mine ? ' · ${l.chatSent}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (message.reactions.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final reaction in message.reactions)
                      ActionChip(
                        label: Text(
                          '${reaction['emoji']} ${reaction['count']}',
                        ),
                        onPressed: () =>
                            context.read<FamilyChatViewModel>().react(
                              message,
                              reaction['emoji'] as String,
                              reaction['mine'] == true,
                            ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedTask extends StatefulWidget {
  const _SharedTask(this.task);
  final Map<String, dynamic> task;
  @override
  State<_SharedTask> createState() => _SharedTaskState();
}

class _SharedTaskState extends State<_SharedTask> {
  Timer? timer;
  void refresh() {
    if (mounted) {
      context.read<FamilyChatViewModel>().refreshTaskPreview(
        widget.task['id'] as String,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void didUpdateWidget(covariant _SharedTask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task['id'] != widget.task['id']) Future.microtask(refresh);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        task =
            context
                .watch<FamilyChatViewModel>()
                .taskPreviews[widget.task['id']] ??
            widget.task;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: AppColors.primary),
        title: Text(
          task['unavailable'] == true
              ? l.chatTaskUnavailable
              : task['title'] as String,
        ),
        subtitle: task['unavailable'] == true
            ? null
            : Text(
                '${taskLabel(context, task['task_type'] as String)} · ${taskLabel(context, task['priority'] as String)} · ${taskLabel(context, task['status'] as String)}',
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: task['unavailable'] == true
            ? null
            : () => context.pushNamed(
                task['task_type'] == 'shopping'
                    ? 'shoppingDetails'
                    : 'taskDetails',
                pathParameters: {'id': task['id'] as String},
              ),
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.message, required this.attachment});
  final ChatMessage message;
  final Map<String, dynamic> attachment;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FamilyChatViewModel>(),
        l = context.taskCopy,
        url = context.watch<FamilyChatViewModel>().imageUrl(
          attachment['id'] as String,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null)
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, _, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.chatImageUnavailable),
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 240,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(l.chatImageUnavailable),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => vm.loadImage(message, attachment),
          icon: const Icon(Icons.image_outlined),
          label: Text(url == null ? l.chatViewImage : l.taskRefreshPhoto),
        ),
      ],
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.item});
  final PendingChatMessage item;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<FamilyChatViewModel>();
    return Align(
      alignment: Alignment.centerRight,
      child: Card(
        color: AppColors.lightBlue,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.body.isNotEmpty) Text(item.body),
              if (item.image != null)
                Image.memory(
                  Uint8List.fromList(item.image!),
                  height: 100,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                ),
              Text(
                item.state == ChatSendState.sending
                    ? item.imageRequired && !item.uploaded
                          ? l.chatUploading
                          : l.chatSending
                    : '${l.chatFailed}: ${chatError(context, item.error)}',
              ),
              if (item.state == ChatSendState.sending)
                const LinearProgressIndicator(),
              if (item.state == ChatSendState.failed)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => vm.retry(item),
                      child: Text(l.retry),
                    ),
                    if (item.imageRequired && !item.uploaded)
                      TextButton(
                        onPressed: () async {
                          try {
                            final bytes = await pickTaskPhoto();
                            if (bytes != null && context.mounted) {
                              item.image = bytes;
                              await vm.retry(item);
                            }
                          } catch (e) {
                            vm.failure(e);
                            vm.emit();
                          }
                        },
                        child: Text(l.chatReselectImage),
                      ),
                    TextButton(
                      onPressed: () => vm.discardPending(item),
                      child: Text(l.chatDiscardPending),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatEditDialog extends StatefulWidget {
  const _ChatEditDialog(this.body);
  final String body;
  @override
  State<_ChatEditDialog> createState() => _ChatEditDialogState();
}

class _ChatEditDialogState extends State<_ChatEditDialog> {
  late final text = TextEditingController(text: widget.body);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return AlertDialog(
      title: Text(l.chatEdit),
      content: Form(
        key: form,
        child: TextFormField(
          controller: text,
          maxLength: 4000,
          maxLines: 4,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l.chatEmptyText : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.taskDismiss),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: Text(l.chatSave),
        ),
      ],
    );
  }
}

class _ChatTaskPicker extends StatefulWidget {
  const _ChatTaskPicker();
  @override
  State<_ChatTaskPicker> createState() => _ChatTaskPickerState();
}

class _ChatTaskPickerState extends State<_ChatTaskPicker> {
  final search = TextEditingController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<FamilyChatViewModel>().findTasks('');
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FamilyChatViewModel>(), l = context.taskCopy;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            children: [
              Text(
                l.chatShareTask,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: search,
                decoration: InputDecoration(labelText: l.taskSearch),
                onChanged: (v) {
                  timer?.cancel();
                  timer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) vm.findTasks(v);
                  });
                },
              ),
              if (vm.taskSearchLoading) const LinearProgressIndicator(),
              if (vm.error != null) Text(chatError(context, vm.error)),
              Expanded(
                child: ListView(
                  children: [
                    for (final task in vm.taskCandidates)
                      ListTile(
                        title: Text(task['title'] as String),
                        subtitle: Text(
                          taskLabel(context, task['task_type'] as String),
                        ),
                        onTap: () => Navigator.pop(context, task),
                      ),
                    if (vm.moreTasks)
                      TextButton(
                        onPressed: vm.taskSearchLoading
                            ? null
                            : () => vm.findTasks(search.text, more: true),
                        child: Text(l.taskLoadMore),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
