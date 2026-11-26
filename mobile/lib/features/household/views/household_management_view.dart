import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../models/household.dart';
import '../models/invitation.dart';
import '../viewmodels/household_actions.dart';
import '../viewmodels/session_view_model.dart';
import 'membership_views.dart' show actionError;

const _outline = Color(0xFF747686);
const _dangerSurface = Color(0xFFFBE9E7);
const _dangerStrong = Color(0xFFBA1A1A);

/// "Household Management" screen (UI/household_management).
class HouseholdManagementView extends StatefulWidget {
  const HouseholdManagementView({super.key});
  @override
  State<HouseholdManagementView> createState() =>
      _HouseholdManagementViewState();
}

class _HouseholdManagementViewState extends State<HouseholdManagementView> {
  late final String householdId;
  @override
  void initState() {
    super.initState();
    householdId = context.read<SessionViewModel>().activeHousehold!.id;
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<HouseholdActions>();
      await vm.reloadMembers(householdId);
      if (!mounted) return;
      if (context.read<SessionViewModel>().activeHousehold?.role == 'admin') {
        await vm.loadInvitations(householdId);
      }
    });
  }

  Future<bool> _confirm(
    String message, {
    String? action,
    bool destructive = false,
  }) async =>
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
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: _dangerStrong)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action ?? l.confirm),
              ),
            ],
          );
        },
      ) ??
      false;

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _afterMembershipEnds() async {
    final session = context.read<SessionViewModel>();
    await session.refresh();
    if (mounted) context.goNamed('selectHousehold');
  }

  Future<void> _edit(HouseholdActions vm, Household household) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _EditSheet(household: household),
    );
    if (result == null || !mounted) return;
    final session = context.read<SessionViewModel>();
    final ok = await vm.update(
      household.id,
      result.name,
      result.description,
      avatarKey: result.avatarKey,
    );
    if (ok && mounted) {
      await session.refresh();
      if (mounted) _snack(AppLocalizations.of(context)!.settingsSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<HouseholdActions>();
    final session = context.watch<SessionViewModel>();
    final household = session.activeHousehold;
    if (household == null) return const SizedBox.shrink();
    final admin = household.role == 'admin';
    final members = vm.members;
    final admins = members.where((m) => m.role == 'admin').toList();
    final soleAdmin = admins.length <= 1;
    final creator = admins.isEmpty ? null : admins.first;
    final count = members.isEmpty ? household.memberCount : members.length;
    final active = vm.invitations
        .where((i) => !i.revoked && i.expiresAt.isAfter(DateTime.now()))
        .toList();
    final me = session.user?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: l.householdSettings,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('profile'),
        onProfile: () => context.goNamed('profile'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 48),
            children: [
              if (vm.error != null) ...[
                Text(
                  vm.error == 'last_admin'
                      ? l.lastAdminError
                      : actionError(l, vm.error),
                  style: AppText.bodySm.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 12),
              ],
              _HeroCard(
                household: household,
                count: count,
                creatorName: creator?.name,
                canEdit: admin,
                onEdit: vm.busy ? null : () => _edit(vm, household),
              ),
              const SizedBox(height: 20),
              _MembersCard(
                members: members,
                admin: admin,
                meId: me,
                soleAdmin: soleAdmin,
                busy: vm.busy,
                onRole: (member, role) =>
                    vm.setMemberRole(householdId, member.userId!, role),
                onRemove: (member) async {
                  if (await _confirm(
                    l.removeMemberConfirm(member.name),
                    action: l.removeMember,
                    destructive: true,
                  )) {
                    await vm.removeMember(householdId, member.userId!);
                  }
                },
                count: count,
              ),
              const SizedBox(height: 20),
              const _RolesCard(),
              if (admin) ...[
                const SizedBox(height: 20),
                _AccessCard(
                  activeDays: active.isEmpty
                      ? null
                      : (active.first.expiresAt
                                    .difference(DateTime.now())
                                    .inHours /
                                24)
                            .ceil()
                            .clamp(1, 99),
                  onInvite: () => context.pushNamed('inviteFamily'),
                ),
              ],
              const SizedBox(height: 20),
              _DangerZone(
                admin: admin,
                soleAdmin: soleAdmin && admin,
                busy: vm.busy,
                onLeave: () async {
                  if (await _confirm(
                        l.leaveConfirm,
                        action: l.leaveHousehold,
                        destructive: true,
                      ) &&
                      mounted) {
                    if (await vm.leave(householdId) && mounted) {
                      await _afterMembershipEnds();
                    }
                  }
                },
                onDelete: () async {
                  if (await _confirm(
                        l.deleteConfirm,
                        action: l.deleteHouseholdButton,
                        destructive: true,
                      ) &&
                      mounted) {
                    if (await vm.deleteHousehold(householdId) && mounted) {
                      await _afterMembershipEnds();
                    }
                  }
                },
              ),
              if (vm.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppLoadingIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.household,
    required this.count,
    required this.creatorName,
    required this.canEdit,
    required this.onEdit,
  });
  final Household household;
  final int count;
  final String? creatorName;
  final bool canEdit;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      HouseholdAvatars.icon(household.avatarKey),
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.sm,
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
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
                            household.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headlineMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppPill(
                          l.statusActive,
                          bg: AppColors.secondaryContainer,
                          fg: AppColors.onSecondaryContainer,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          l.membersCount(count),
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        if (creatorName != null) ...[
                          const SizedBox.square(
                            dimension: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Text(
                            l.createdByName(creatorName!),
                            style: AppText.bodySm.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            AppCta(
              label: l.editHousehold,
              icon: Icons.tune,
              color: AppColors.surfaceContainer,
              foreground: AppColors.primary,
              shadow: false,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.members,
    required this.admin,
    required this.meId,
    required this.soleAdmin,
    required this.busy,
    required this.onRole,
    required this.onRemove,
    required this.count,
  });
  final List<HouseholdMember> members;
  final bool admin;
  final String? meId;
  final bool soleAdmin;
  final bool busy;
  final void Function(HouseholdMember, String) onRole;
  final void Function(HouseholdMember) onRemove;
  final int count;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l.membersHeading,
                    style: AppText.headlineSm.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: AppText.labelSm.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              Text(
                l.membersSubtitle,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          radius: 20,
          padding: const EdgeInsetsDirectional.all(6),
          child: Column(
            children: [
              for (final member in members)
                _MemberRow(
                  member: member,
                  isMe: member.userId != null && member.userId == meId,
                  soleAdmin: soleAdmin,
                  canManage: admin && !busy,
                  onRole: onRole,
                  onRemove: onRemove,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.soleAdmin,
    required this.canManage,
    required this.onRole,
    required this.onRemove,
  });
  final HouseholdMember member;
  final bool isMe;
  final bool soleAdmin;
  final bool canManage;
  final void Function(HouseholdMember, String) onRole;
  final void Function(HouseholdMember) onRemove;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAdmin = member.role == 'admin';
    final subtitle = isAdmin && soleAdmin && isMe
        ? l.creatorSoleAdmin
        : member.joinedAt == null
        ? ''
        : l.joinedWhen(relativeTime(l, member.joinedAt!));
    return Padding(
      padding: const EdgeInsetsDirectional.all(8),
      child: Row(
        children: [
          InitialsAvatar(
            member.name,
            bg: isMe ? AppColors.primaryFixed : AppColors.surfaceContainer,
            fg: isMe ? AppColors.onPrimaryFixed : AppColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleMd.copyWith(color: AppColors.text),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      AppPill(
                        l.youBadge,
                        bg: AppColors.surfaceContainer,
                        fg: AppColors.primary,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        style: AppText.labelSm.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppPill(
            isAdmin ? l.adminRole : l.memberRole,
            bg: isAdmin
                ? AppColors.primary.withAlpha(26)
                : AppColors.surfaceHigh,
            fg: isAdmin ? AppColors.primary : AppColors.muted,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            style: AppText.labelSm.copyWith(
              fontWeight: isAdmin ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
          if (isMe || !canManage || member.userId == null)
            SizedBox(
              width: 40,
              height: 40,
              child: isMe && isAdmin && soleAdmin
                  ? Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: _outline.withAlpha(153),
                    )
                  : null,
            )
          else
            PopupMenuButton<String>(
              tooltip: l.memberOptions(member.name),
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.muted,
              ),
              iconSize: 20,
              onSelected: (value) {
                if (value == 'remove') {
                  onRemove(member);
                } else {
                  onRole(member, value);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: isAdmin ? 'member' : 'admin',
                  child: Text(isAdmin ? l.makeMember : l.makeAdmin),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    l.removeMember,
                    style: const TextStyle(color: _dangerStrong),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RolesCard extends StatelessWidget {
  const _RolesCard();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final body = AppText.bodySm.copyWith(color: AppColors.muted, height: 1.625);
    final strong = body.copyWith(
      color: AppColors.text,
      fontWeight: FontWeight.w600,
    );
    return AppCard(
      color: AppColors.surfaceContainer,
      radius: 20,
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 2),
            child: IconTile(
              icon: Icons.admin_panel_settings_outlined,
              bg: AppColors.primaryContainer,
              fg: Color(0xFFF5F3FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.rolesPermissions,
                  style: AppText.titleMd.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: body,
                    children: [
                      TextSpan(text: l.rolesAdminsLabel, style: strong),
                      TextSpan(text: l.rolesAdminsText),
                      TextSpan(text: l.rolesMembersLabel, style: strong),
                      TextSpan(text: l.rolesMembersText),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.activeDays, required this.onInvite});
  final int? activeDays;
  final VoidCallback onInvite;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.householdAccess,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              Text(
                l.householdAccessSubtitle,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          radius: 20,
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const IconTile(
                    icon: Icons.person_add_alt,
                    bg: AppColors.secondaryContainer,
                    fg: AppColors.onSecondaryContainer,
                    size: 40,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.inviteNewMember,
                          style: AppText.titleMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          l.inviteNewMemberSubtitle,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppCta(
                label: l.generateCode,
                icon: Icons.add,
                color: AppColors.primary,
                onPressed: onInvite,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.surfaceHighest),
              const SizedBox(height: 16),
              InkWell(
                onTap: onInvite,
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.key,
                      bg: AppColors.surfaceContainer,
                      fg: AppColors.muted,
                      size: 40,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.manageInviteCodes,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                          Row(
                            children: [
                              if (activeDays != null) ...[
                                const SizedBox.square(
                                  dimension: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  activeDays == null
                                      ? l.noActiveCodeShort
                                      : l.activeCodeDays(activeDays!),
                                  style: AppText.bodySm.copyWith(
                                    color: activeDays == null
                                        ? AppColors.muted
                                        : AppColors.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: AppColors.muted,
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

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.admin,
    required this.soleAdmin,
    required this.busy,
    required this.onLeave,
    required this.onDelete,
  });
  final bool admin;
  final bool soleAdmin;
  final bool busy;
  final VoidCallback onLeave;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 22,
                    color: _dangerStrong,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.dangerZone,
                    style: AppText.headlineSm.copyWith(color: _dangerStrong),
                  ),
                ],
              ),
              Text(
                l.dangerSubtitle,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: _dangerSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.leaveHousehold,
                style: AppText.titleMd.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                soleAdmin ? l.leaveSoleAdminText : l.leaveText,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              AppCta(
                label: l.leaveHousehold,
                icon: Icons.logout,
                color: Colors.white,
                foreground: _dangerStrong,
                shadow: false,
                onPressed: busy || soleAdmin ? null : onLeave,
              ),
              if (admin) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0x1A000000)),
                const SizedBox(height: 16),
                Text(
                  l.deleteHouseholdTitle,
                  style: AppText.titleMd.copyWith(color: _dangerStrong),
                ),
                const SizedBox(height: 4),
                Text(
                  l.deleteHouseholdText,
                  style: AppText.bodySm.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                AppCta(
                  label: l.deleteHouseholdButton,
                  icon: Icons.delete_forever_outlined,
                  color: _dangerStrong,
                  onPressed: busy ? null : onDelete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditResult {
  const _EditResult(this.name, this.description, this.avatarKey);
  final String name;
  final String? description;
  final String avatarKey;
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.household});
  final Household household;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final name = TextEditingController(text: widget.household.name);
  late final description = TextEditingController(
    text: widget.household.description ?? '',
  );
  late String avatar = widget.household.avatarKey ?? 'cottage';
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.editHouseholdTitle,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final key in HouseholdAvatars.keys)
                    Material(
                      color: key == avatar
                          ? AppColors.surfaceHigh
                          : AppColors.surfaceLow,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => avatar = key),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            HouseholdAvatars.icon(key, filled: key == avatar),
                            size: 22,
                            color: key == avatar
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l.householdNameLabel,
                controller: name,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                child: Text(
                  l.householdDescriptionLabel,
                  style: AppText.labelMd.copyWith(color: AppColors.muted),
                ),
              ),
              TextFormField(
                controller: description,
                maxLength: 1000,
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              AppCta(
                label: l.saveChanges,
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  final text = description.text.trim();
                  Navigator.pop(
                    context,
                    _EditResult(
                      name.text.trim(),
                      text.isEmpty ? null : text,
                      avatar,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
