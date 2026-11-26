import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../models/invitation.dart';
import '../viewmodels/household_actions.dart';
import '../viewmodels/session_view_model.dart';
import 'membership_views.dart' show actionError;

/// "Invite Family Members" screen (UI/invite_family_members).
class InviteView extends StatefulWidget {
  const InviteView({super.key});
  @override
  State<InviteView> createState() => _InviteViewState();
}

class _InviteViewState extends State<InviteView> {
  late final String householdId;
  @override
  void initState() {
    super.initState();
    final session = context.read<SessionViewModel>();
    householdId = session.activeHousehold!.id;
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<HouseholdActions>();
      await vm.loadInvitations(householdId);
      if (!mounted) return;
      await vm.reloadMembers(householdId);
      // A freshly created household gets its first code without another tap.
      if (mounted && session.inviteAfterCreate && vm.issued == null) {
        if (!_activeInvites(vm).isNotEmpty) await vm.issue(householdId);
      }
    });
  }

  List<Invitation> _activeInvites(HouseholdActions vm) => vm.invitations
      .where(
        (i) =>
            !i.revoked &&
            i.expiresAt.isAfter(DateTime.now()) &&
            (i.maxUses == null || i.uses < i.maxUses!),
      )
      .toList();

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.confirm),
              ),
            ],
          );
        },
      ) ??
      false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF283041),
          shape: const StadiumBorder(),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.secondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                message,
                style: AppText.labelMd.copyWith(color: const Color(0xFFEDF0FF)),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _copy(String code, AppLocalizations l) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast(l.copied);
  }

  Future<void> _share(
    BuildContext buttonContext,
    String code,
    String name,
    AppLocalizations l,
  ) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: l.invitationShare(name, code),
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on Object {
      if (mounted) _toast(l.operationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<HouseholdActions>();
    final session = context.watch<SessionViewModel>();
    final household = session.activeHousehold;
    final name = household?.name ?? '';
    final code = vm.issued?.code;
    final active = _activeInvites(vm);
    final expiry =
        vm.issued?.invitation.expiresAt ??
        (active.isEmpty ? null : active.first.expiresAt);
    final days = expiry == null
        ? null
        : (expiry.difference(DateTime.now()).inHours / 24).ceil().clamp(1, 99);
    final admin = vm.members.where((m) => m.role == 'admin').firstOrNull;
    final count = vm.members.isEmpty
        ? (household?.memberCount ?? 1)
        : vm.members.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: l.inviteFamily,
        onBack: () {
          session.finishInvitation();
          context.canPop() ? context.pop() : context.goNamed('home');
        },
        onProfile: () => context.goNamed('profile'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
              children: [
                AppPill(
                  l.inviteSetupBadge.toUpperCase(),
                  icon: Icons.group_add,
                  bg: AppColors.secondaryContainer,
                  fg: AppColors.onSecondaryContainer,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  style: AppText.labelSm.copyWith(letterSpacing: 0.55),
                ).wrapAlign(),
                const SizedBox(height: 4),
                Text(
                  l.inviteYourFamily,
                  style: AppText.headlineLg.copyWith(
                    color: AppColors.text,
                    letterSpacing: -0.65,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.inviteSubtitle,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    actionError(l, vm.error),
                    style: AppText.bodySm.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 20),
                _IdentityCard(
                  name: name,
                  avatarKey: household?.avatarKey,
                  subtitle: admin == null
                      ? l.membersCount(count)
                      : l.createdByMembers(admin.name, count),
                  members: vm.members,
                  activeLabel: l.membersActiveCap(count),
                ),
                const SizedBox(height: 20),
                _CodeCard(
                  l: l,
                  code: code,
                  days: days,
                  busy: vm.busy,
                  expiryText: expiry == null
                      ? null
                      : l.activeCodeExpires(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(expiry.toLocal()),
                        ),
                  onCopy: code == null ? null : () => _copy(code, l),
                  onShare: code == null
                      ? null
                      : (buttonContext) => _share(buttonContext, code, name, l),
                  onGenerate: () async {
                    if (active.isNotEmpty &&
                        !await _confirm(l.replaceCodeQuestion)) {
                      return;
                    }
                    if (mounted) await vm.issue(householdId);
                  },
                ),
                if (code != null) ...[
                  const SizedBox(height: 20),
                  _MessagePreview(l: l, name: name, code: code),
                ],
                const SizedBox(height: 20),
                _MembersList(l: l, members: vm.members),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LinkAction(
                      icon: Icons.autorenew,
                      label: l.generateCode,
                      color: AppColors.primary,
                      onTap: vm.busy
                          ? null
                          : () async {
                              if (active.isNotEmpty &&
                                  !await _confirm(l.replaceCodeQuestion)) {
                                return;
                              }
                              if (mounted) await vm.issue(householdId);
                            },
                    ),
                    if (active.isNotEmpty)
                      _LinkAction(
                        icon: Icons.cancel_outlined,
                        label: l.revokeExisting,
                        color: AppColors.danger,
                        iconSize: 18,
                        onTap: vm.busy
                            ? null
                            : () async {
                                if (await _confirm(l.revokeCodeQuestion) &&
                                    mounted) {
                                  await vm.revoke(householdId, active.first.id);
                                }
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Text(
                    l.codeExpiryNote,
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                ),
                if (vm.busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppLoadingIndicator(),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00F9F9FF), AppColors.background],
              ),
            ),
            child: SafeArea(
              top: false,
              child: AppCta(
                label: l.doneGoDashboard,
                trailingIcon: Icons.arrow_forward,
                onPressed: () {
                  session.finishInvitation();
                  context.goNamed('home');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget wrapAlign() =>
      Align(alignment: AlignmentDirectional.centerStart, child: this);
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.avatarKey,
    required this.subtitle,
    required this.members,
    required this.activeLabel,
  });
  final String name;
  final String? avatarKey;
  final String subtitle;
  final List<HouseholdMember> members;
  final String activeLabel;
  @override
  Widget build(BuildContext context) {
    final shown = members.take(2).toList();
    final extra = members.length - shown.length;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(51),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      HouseholdAvatars.icon(avatarKey),
                      size: 28,
                      color: Colors.white,
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headlineSm.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 32,
                  width: shown.isEmpty
                      ? 0
                      : ((shown.length + (extra > 0 ? 1 : 0)) - 1) * 24.0 + 32,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * 24.0,
                          child: _Ringed(
                            InitialsAvatar(
                              shown[i].name,
                              size: 32,
                              bg: _avatarColors[i % 3].$1,
                              fg: _avatarColors[i % 3].$2,
                            ),
                          ),
                        ),
                      if (extra > 0)
                        Positioned(
                          left: shown.length * 24.0,
                          child: _Ringed(
                            InitialsAvatar(
                              '+$extra',
                              size: 32,
                              bg: AppColors.surfaceContainer,
                              fg: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeLabel,
                      style: AppText.labelMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

const _avatarColors = [
  (AppColors.tertiaryFixed, AppColors.onTertiaryFixed),
  (AppColors.primaryFixed, AppColors.onPrimaryFixed),
  (AppColors.secondaryFixed, Color(0xFF002113)),
];

class _Ringed extends StatelessWidget {
  const _Ringed(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: AppShadows.sm,
    ),
    child: child,
  );
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.l,
    required this.code,
    required this.days,
    required this.busy,
    required this.expiryText,
    required this.onCopy,
    required this.onShare,
    required this.onGenerate,
  });
  final AppLocalizations l;
  final String? code;
  final int? days;
  final bool busy;
  final String? expiryText;
  final VoidCallback? onCopy;
  final void Function(BuildContext)? onShare;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppShadows.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l.inviteCodeTitle.toUpperCase(),
                style: AppText.labelMd.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (days != null)
              AppPill(
                l.validDays(days!),
                icon: Icons.lock_open,
                bg: AppColors.secondaryContainer,
                fg: AppColors.onSecondaryContainer,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code != null
                            ? l.tapToCopy
                            : expiryText != null
                            ? l.activeCodeLabel
                            : l.noActiveCode,
                        style: AppText.labelSm.copyWith(color: AppColors.muted),
                      ),
                      if (code != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: SelectableText(
                            code!,
                            style: AppText.headlineLg.copyWith(
                              fontSize: 32,
                              height: 40 / 32,
                              color: AppColors.primary,
                              letterSpacing: 1.6,
                            ),
                          ),
                        )
                      else
                        Text(
                          expiryText ?? l.noActiveCodeBody,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.sm,
                  ),
                  child: IconButton(
                    tooltip: l.copyCode,
                    onPressed: onCopy,
                    icon: const Icon(
                      Icons.content_copy,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          code == null ? l.codeShownOnce : l.codeShareHelp,
          style: AppText.bodySm.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppCta(
                label: l.copyCode,
                icon: Icons.content_copy,
                color: AppColors.surfaceHigh,
                foreground: AppColors.primary,
                shadow: false,
                onPressed: onCopy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Builder(
                builder: (buttonContext) => AppCta(
                  label: l.shareInvitation,
                  icon: Icons.share,
                  onPressed: onShare == null
                      ? null
                      : () => onShare!(buttonContext),
                ),
              ),
            ),
          ],
        ),
        if (code == null) ...[
          const SizedBox(height: 8),
          AppCta(
            label: l.generateCode,
            icon: Icons.autorenew,
            loading: busy,
            onPressed: onGenerate,
          ),
        ],
      ],
    ),
  );
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    required this.l,
    required this.name,
    required this.code,
  });
  final AppLocalizations l;
  final String name;
  final String code;
  @override
  Widget build(BuildContext context) {
    final body = AppText.bodySm.copyWith(color: AppColors.text, height: 1.625);
    final strong = body.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );
    return AppCard(
      color: AppColors.surfaceLow,
      radius: 20,
      shadow: false,
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble,
                size: 18,
                color: AppColors.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                l.inviteMessagePreview,
                style: AppText.labelMd.copyWith(color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.sm,
            ),
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  TextSpan(text: l.previewPre),
                  TextSpan(text: name, style: strong),
                  TextSpan(text: l.previewMid),
                  TextSpan(text: code, style: strong),
                  TextSpan(text: l.previewPost),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.l, required this.members});
  final AppLocalizations l;
  final List<HouseholdMember> members;
  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.familyMembers,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              Text(
                l.joinedCount(members.length),
                style: AppText.labelSm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          radius: 20,
          padding: const EdgeInsetsDirectional.all(4),
          child: Column(
            children: [
              for (var i = 0; i < members.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsetsDirectional.all(8),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        members[i].name,
                        size: 40,
                        bg: _avatarColors[i % 3].$1,
                        fg: _avatarColors[i % 3].$2,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              members[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.titleMd.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                            if (members[i].joinedAt != null)
                              Text(
                                l.joinedOn(
                                  material.formatShortMonthDay(
                                    members[i].joinedAt!.toLocal(),
                                  ),
                                ),
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppPill(
                        l.joinedPill,
                        icon: Icons.check_circle_outline,
                        bg: AppColors.secondaryContainer,
                        fg: AppColors.onSecondaryContainer,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconSize = 20,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double iconSize;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppText.labelMd.copyWith(color: color)),
        ],
      ),
    ),
  );
}
