import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
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

  Future<void> chooseMention() async {
    final vm = model!,
        captured = model!.scope,
        tasks = context.read<TasksViewModel>();
    await tasks.loadMembers();
    if (!mounted || !vm.current(captured)) return;
    final member = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: ListView(
            children: [
              ListTile(title: Text(context.taskCopy.hubMention)),
              for (final row in tasks.members)
                ListTile(
                  title: Text(
                    row['display_name'] as String? ??
                        context.taskCopy.hubMember,
                  ),
                  onTap: () => Navigator.pop(context, row),
                ),
            ],
          ),
        ),
      ),
    );
    if (member != null && mounted && vm.current(captured)) {
      vm.mention(
        member['user_id'] as String,
        member['display_name'] as String? ?? context.taskCopy.hubMember,
      );
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

  Future<void> convertTo(ChatMessage message, TaskKind type) async {
    final vm = model!, captured = model!.scope;
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FamilyChatViewModel>(),
        l = context.taskCopy,
        home = vm.session.activeHousehold,
        rows = vm.messages;
    final compactComposer =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 21;
    Widget composerButton(String tip, IconData icon, VoidCallback? onTap) =>
        IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 26, color: AppColors.muted),
        );
    final composerActions = [
      composerButton(
        l.chatShareTask,
        Icons.add_circle_outline,
        vm.sending ? null : shareTask,
      ),
      composerButton(
        l.chatAttach,
        Icons.photo_camera_outlined,
        vm.sending ? null : chooseImage,
      ),
      composerButton(
        l.hubMention,
        Icons.alternate_email,
        vm.sending ? null : chooseMention,
      ),
    ];
    return AppScaffold(
      title: l.chatTitle,
      appBar: BrandAppBar(
        title: l.appName,
        onProfile: () => context.goNamed('profile'),
        actions: [
          IconButton(
            tooltip: l.taskRefresh,
            onPressed: vm.loading ? null : () => vm.load(),
            icon: const Icon(Icons.refresh, color: AppColors.text),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    HouseholdAvatars.icon(home?.avatarKey),
                    size: 24,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        home?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        l.chatMembers(home?.memberCount ?? 0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd.copyWith(
                          color: AppColors.muted,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.familyMembers,
                  onPressed: () => context.pushNamed('members'),
                  icon: const Icon(Icons.info_outline, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (vm.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              children: [
                if (!vm.connected)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
                    child: Text(
                      l.chatReconnecting,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ),
                if (vm.cached)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      l.chatCached,
                      style: AppText.bodySm.copyWith(color: AppColors.primary),
                    ),
                  ),
                if (vm.cacheError)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l.chatCacheError),
                  ),
                if (vm.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      chatError(context, vm.error),
                      style: AppText.bodySm.copyWith(color: AppColors.danger),
                    ),
                  ),
                if (vm.hasOlder)
                  TextButton(
                    onPressed: vm.olderLoading ? null : older,
                    child: Text(l.chatOlder),
                  ),
                if (vm.olderLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (rows.isEmpty && vm.pending.isEmpty && !vm.loading)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const IconTile(
                          icon: Icons.forum_outlined,
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.primary,
                          size: 64,
                          iconSize: 32,
                          radius: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.chatEmpty,
                          textAlign: TextAlign.center,
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i == 0 ||
                      DateUtils.dateOnly(rows[i - 1].created.toLocal()) !=
                          DateUtils.dateOnly(rows[i].created.toLocal()))
                    Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 12,
                        ),
                        child: AppPill(
                          _dayLabel(l, rows[i].created.toLocal()),
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.muted,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          style: AppText.labelMd.copyWith(letterSpacing: 0),
                        ),
                      ),
                    ),
                  _ChatBubble(
                    message: rows[i],
                    mine: rows[i].sender == vm.user,
                    onLongPress: () => actions(rows[i]),
                    onCreateTask: () => convert(rows[i]),
                    onAddShopping: () => convertTo(rows[i], TaskKind.shopping),
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
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.mentions.isNotEmpty)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final entry in vm.mentions.entries)
                              InputChip(
                                label: Text('@${entry.value}'),
                                onDeleted: () => vm.removeMention(entry.key),
                              ),
                          ],
                        ),
                      ),
                    if (vm.replyId != null)
                      Container(
                        margin: const EdgeInsetsDirectional.only(
                          start: 8,
                          bottom: 8,
                        ),
                        padding: const EdgeInsetsDirectional.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.reply, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vm.replying?.senderName ?? l.chatReply,
                                    style: AppText.labelMd.copyWith(
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    vm.replying?.body ?? l.chatReplyUnavailable,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodySm.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l.taskDismiss,
                              onPressed: () => vm.reply(null),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    if (vm.selectedImage != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                vm.selectedImage!,
                                height: 72,
                                width: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                            IconButton(
                              tooltip: l.taskRemovePhoto,
                              onPressed: () => vm.photo(null),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    if (compactComposer)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(children: composerActions),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!compactComposer) ...composerActions,
                        Expanded(
                          child: TextField(
                            controller: composer,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 4000,
                            style: AppText.bodyLg.copyWith(
                              color: AppColors.text,
                            ),
                            onChanged: (body) {
                              vm.changeDraft(body);
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: l.chatComposer,
                              counterText: '',
                              fillColor: AppColors.surfaceContainer,
                              contentPadding:
                                  const EdgeInsetsDirectional.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9999),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9999),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color:
                              !vm.ready ||
                                  vm.sending ||
                                  (composer.text.trim().isEmpty &&
                                      vm.selectedImage == null)
                              ? AppColors.surfaceHighest
                              : AppColors.primary,
                          shape: const CircleBorder(),
                          child: IconButton(
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
                            icon: const Icon(
                              Icons.send_outlined,
                              color: Colors.white,
                            ),
                          ),
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

String _dayLabel(AppLocalizations l, DateTime day) {
  final today = DateUtils.dateOnly(DateTime.now());
  final d = DateUtils.dateOnly(day);
  if (d == today) return l.taskToday;
  if (d == today.subtract(const Duration(days: 1))) return l.hubYesterday;
  return DateFormat.yMMMd().format(day);
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
    required this.onCreateTask,
    required this.onAddShopping,
  });
  final ChatMessage message;
  final bool mine;
  final VoidCallback onLongPress;
  final VoidCallback onCreateTask;
  final VoidCallback onAddShopping;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final name = message.senderName?.isNotEmpty == true
        ? message.senderName!
        : l.taskFormerMember;
    final (avBg, avFg) = taskAvatarColors(name);
    final text = message.deleted ? l.chatDeleted : message.body;
    final time =
        '${DateFormat.jm().format(message.created.toLocal())}${message.edited ? ' · ${l.chatEdited}' : ''}';
    final bubble = Material(
      color: mine ? AppColors.primary : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(mine ? 16 : 4),
        bottomRight: Radius.circular(mine ? 4 : 16),
      ),
      child: InkWell(
        onLongPress: message.deleted ? null : onLongPress,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        child: Ink(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            boxShadow: mine ? null : AppShadows.sm,
          ),
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
                        : AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.reply!['deleted'] == true
                        ? l.chatReplyUnavailable
                        : '${message.reply!['sender_name'] ?? l.taskFormerMember}\n${message.reply!['body'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(
                      color: mine ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              if (message.deleted || message.body.isNotEmpty)
                Text(
                  text,
                  style: AppText.bodyLg.copyWith(
                    color: mine ? Colors.white : AppColors.text,
                    fontStyle: message.deleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              for (final attachment in message.attachments)
                _ChatImage(message: message, attachment: attachment),
            ],
          ),
        ),
      ),
    );
    final shared = [for (final task in message.tasks) _SharedTask(task)];
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: mine
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .82,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    bubble,
                    ...shared,
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: AppText.labelSm.copyWith(
                              color: AppColors.muted,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.done_all,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.chatSent,
                            style: AppText.labelSm.copyWith(
                              color: AppColors.muted,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Reactions(message: message, alignEnd: true),
                  ],
                ),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(name, size: 36, bg: avBg, fg: avFg),
                const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 4),
                          child: Text(
                            name,
                            style: AppText.labelMd.copyWith(
                              color: AppColors.muted,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        bubble,
                        ...shared,
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 4),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                time,
                                style: AppText.labelSm.copyWith(
                                  color: AppColors.muted,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (!message.deleted &&
                                  message.body.isNotEmpty) ...[
                                _ActionChip(
                                  icon: Icons.add_task,
                                  label: l.chatCreateTaskChip,
                                  onTap: onCreateTask,
                                ),
                                _ActionChip(
                                  icon: Icons.add_shopping_cart,
                                  label: l.chatAddShoppingChip,
                                  onTap: onAddShopping,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _Reactions(message: message, alignEnd: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainer,
    borderRadius: BorderRadius.circular(9999),
    child: InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppText.labelSm.copyWith(
                color: AppColors.primary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Reactions extends StatelessWidget {
  const _Reactions({required this.message, required this.alignEnd});
  final ChatMessage message;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6),
      child: Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        spacing: 6,
        children: [
          for (final reaction in message.reactions)
            ActionChip(
              label: Text('${reaction['emoji']} ${reaction['count']}'),
              onPressed: () => context.read<FamilyChatViewModel>().react(
                message,
                reaction['emoji'] as String,
                reaction['mine'] == true,
              ),
            ),
        ],
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
    final unavailable = task['unavailable'] == true;
    final type = task['task_type'] as String?;
    final priority = task['priority'] as String?;
    final status = task['status'] as String?;
    final urgent = priority == 'urgent';
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: unavailable
              ? null
              : () => context.pushNamed(
                  type == 'shopping' ? 'shoppingDetails' : 'taskDetails',
                  pathParameters: {'id': task['id'] as String},
                ),
          child: Ink(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unavailable)
                  Text(
                    l.chatTaskUnavailable,
                    style: AppText.titleMd.copyWith(color: AppColors.text),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              taskKindIcon(
                                TaskKind.values.byName(type ?? 'general'),
                              ),
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l.chatSharedKind(
                                  taskLabel(context, type ?? 'general'),
                                ),
                                style: AppText.labelMd.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (priority != null)
                        AppPill(
                          taskLabel(context, priority),
                          bg: urgent
                              ? const Color(0xFFFFDAD6)
                              : AppColors.primaryFixed,
                          fg: urgent ? AppColors.danger : AppColors.primary,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      if (status != null) ...[
                        const SizedBox(width: 4),
                        AppPill(
                          taskLabel(context, status),
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.primary,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task['title'] as String,
                    style: AppText.headlineSm.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.chatViewTask,
                          style: AppText.labelLg.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
