import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/appearance/appearance_model.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../auth/models/form_validation.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../viewmodels/household_actions.dart';
import '../viewmodels/session_view_model.dart';

const _outlineVariant = Color(0xFFC4C5D7);
const _deleteAccountUrl =
    'https://abdul-hadi-jalil.github.io/homecircle/delete-account.html';

/// "Profile & Settings" screen (UI/profile_settings).
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<HouseholdActions>();
      final session = context.read<SessionViewModel>();
      unawaited(context.read<NotificationsViewModel>().loadPreferences());
      await vm.loadProfile();
      final id = session.activeHousehold?.id;
      if (id != null && mounted) {
        await vm.loadMyActivity(id);
        if (mounted) await vm.reloadMembers(id);
      }
    });
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editProfile(HouseholdActions vm) async {
    final l = AppLocalizations.of(context)!;
    final current = vm.profile?['display_name'] as String? ?? '';
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _NameSheet(initial: current),
    );
    if (name == null || !mounted) return;
    final session = context.read<SessionViewModel>();
    if (await vm.saveProfile(name) && mounted) {
      await session.refresh();
      if (mounted) _toast(l.profileSaved);
    }
  }

  Future<void> _changePassword() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _PasswordSheet(),
    );
    if (ok == true && mounted) _toast(l.passwordChangedToast);
  }

  void _info(String title, List<(String?, String)> sections) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              for (final section in sections) ...[
                const SizedBox(height: 16),
                if (section.$1 != null) ...[
                  Text(
                    section.$1!,
                    style: AppText.labelLg.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  section.$2,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(SessionViewModel session) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SignOutSheet(household: session.activeHousehold?.name ?? '', l: l),
    );
    if (confirmed == true) await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<HouseholdActions>();
    final session = context.watch<SessionViewModel>();
    final notifications = context.watch<NotificationsViewModel>();
    final appearance = context.watch<AppearanceModel>();
    final household = session.activeHousehold;
    final admin = household?.role == 'admin';
    final name =
        (vm.profile?['display_name'] as String?)?.trim().isNotEmpty == true
        ? (vm.profile!['display_name'] as String).trim()
        : l.hubMember;
    final email = vm.profile?['email'] as String? ?? session.user?.email ?? '';
    final pushOn = notifications.preferences['push_enabled'] as bool? ?? true;
    final count = vm.members.isEmpty
        ? (household?.memberCount ?? 1)
        : vm.members.length;
    return AppScaffold(
      title: l.profile,
      appBar: BrandAppBar(title: l.appName, onProfile: () {}),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.profileTitle,
                          style: AppText.headlineLg.copyWith(
                            color: AppColors.text,
                            letterSpacing: -0.65,
                          ),
                        ),
                        Text(
                          l.profileSubtitle,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.surfaceContainer,
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.pushNamed('notificationSettings'),
                      child: Tooltip(
                        message: l.quickSettings,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.tune,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  l.operationFailed,
                  style: AppText.bodySm.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 20),
              AppCard(
                radius: 20,
                padding: const EdgeInsetsDirectional.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            InitialsAvatar(
                              name,
                              size: 64,
                              bg: AppColors.tertiaryFixed,
                              fg: AppColors.onTertiaryFixed,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const SizedBox.square(
                                  dimension: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.headlineSm.copyWith(
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (household != null)
                                    AppPill(
                                      admin
                                          ? l.householdAdminBadge
                                          : l.householdMemberBadge,
                                      bg: AppColors.primaryFixed,
                                      fg: AppColors.primary,
                                      padding:
                                          const EdgeInsetsDirectional.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                      style: AppText.labelSm.copyWith(
                                        letterSpacing: 0,
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      label: l.editProfile,
                      icon: Icons.edit_outlined,
                      color: AppColors.surfaceLow,
                      foreground: AppColors.primary,
                      shadow: false,
                      onPressed: vm.profile == null || vm.busy
                          ? null
                          : () => _editProfile(vm),
                    ),
                  ],
                ),
              ),
              if (household != null) ...[
                const SizedBox(height: 20),
                AppCard(
                  radius: 20,
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryFixed,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              HouseholdAvatars.icon(
                                household.avatarKey,
                                filled: false,
                              ),
                              size: 24,
                              color: AppColors.primary,
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
                                        household.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.titleMd.copyWith(
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.verified_outlined,
                                      size: 16,
                                      color: AppColors.secondary,
                                    ),
                                  ],
                                ),
                                Text(
                                  l.myHouseholdLine(
                                    count,
                                    admin
                                        ? l.adminControlsRole
                                        : l.memberAccessRole,
                                  ),
                                  style: AppText.bodySm.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            height: 32,
                            width: _stackWidth(vm.members.length),
                            child: Stack(
                              children: [
                                for (
                                  var i = 0;
                                  i < vm.members.take(3).length;
                                  i++
                                )
                                  Positioned(
                                    left: i * 20.0,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: InitialsAvatar(
                                        vm.members[i].name,
                                        size: 28,
                                        bg: _palette[i % 3].$1,
                                        fg: _palette[i % 3].$2,
                                      ),
                                    ),
                                  ),
                                if (vm.members.length > 3)
                                  Positioned(
                                    left: 3 * 20.0,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: InitialsAvatar(
                                        '+${vm.members.length - 3}',
                                        size: 28,
                                        bg: AppColors.surfaceHigh,
                                        fg: AppColors.text,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: InkWell(
                              onTap: () => context.pushNamed(
                                admin ? 'householdSettings' : 'members',
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        l.manageHousehold,
                                        style: AppText.labelMd.copyWith(
                                          color: AppColors.primary,
                                        ),
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
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel(l.myActivity, trailing: l.liveOverview),
                const SizedBox(height: 4),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.assignment_turned_in_outlined,
                      iconFg: AppColors.primary,
                      title: l.myAssignedTasks,
                      pill: l.countActive(vm.assignedActive),
                      pillBg: AppColors.primaryFixed,
                      pillFg: AppColors.primary,
                      onTap: () => context.goNamed(
                        'tasks',
                        queryParameters: {'active': 'true', 'assignment': 'me'},
                      ),
                    ),
                    _Row(
                      icon: Icons.shopping_cart_checkout,
                      iconFg: AppColors.tertiaryContainer,
                      title: l.myRequests,
                      pill: l.countOpen(vm.requestsOpen),
                      pillBg: AppColors.tertiaryFixed,
                      pillFg: AppColors.onTertiaryFixed,
                      onTap: () => context.goNamed(
                        'tasks',
                        queryParameters: {
                          'active': 'true',
                          'assignment': 'requested',
                        },
                      ),
                    ),
                    _Row(
                      icon: Icons.task_alt,
                      iconFg: AppColors.secondary,
                      title: l.myCompletedTasks,
                      pill: l.countDone(vm.completedMine),
                      pillBg: AppColors.secondaryContainer,
                      pillFg: AppColors.onSecondaryContainer,
                      onTap: () => context.goNamed(
                        'tasks',
                        queryParameters: {
                          'assignment': 'me',
                          'status': 'completed',
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel(l.preferencesHeading),
              const SizedBox(height: 4),
              _Group(
                children: [
                  _Row(
                    icon: Icons.notifications_outlined,
                    title: l.notifications,
                    subtitle: pushOn ? l.notifSubOn : l.notifSubOff,
                    onTap: () => context.pushNamed('notificationSettings'),
                    trailing: Switch(
                      value: pushOn,
                      onChanged: notifications.preferencesBusy
                          ? null
                          : (value) => notifications.setPreference(
                              'push_enabled',
                              value,
                            ),
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: AppColors.surfaceHighest,
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ),
                  ),
                  _Row(
                    icon: Icons.translate,
                    title: l.appLanguage,
                    value: l.languageValue,
                    chevron: false,
                  ),
                  _Row(
                    icon: Icons.palette_outlined,
                    title: l.appearance,
                    value: l.appearanceValue,
                    chevron: false,
                  ),
                  _Row(
                    icon: Icons.accessibility_new,
                    title: l.highContrast,
                    subtitle: appearance.highContrast
                        ? l.highContrastOn
                        : l.highContrastOff,
                    onTap: () =>
                        appearance.setHighContrast(!appearance.highContrast),
                    trailing: Switch(
                      value: appearance.highContrast,
                      onChanged: appearance.setHighContrast,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: AppColors.surfaceHighest,
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(l.accountSecurity),
              const SizedBox(height: 4),
              _Group(
                children: [
                  _Row(
                    icon: Icons.lock_reset,
                    title: l.changePassword,
                    onTap: _changePassword,
                  ),
                  _Row(
                    icon: Icons.security,
                    title: l.privacySecurity,
                    onTap: () =>
                        _info(l.privacySecurity, [(null, l.privacyBody)]),
                  ),
                  _Row(
                    icon: Icons.help_outline,
                    title: l.helpSupport,
                    onTap: () => _info(l.helpSupport, [
                      (l.faqJoinQ, l.faqJoinA),
                      (l.faqCodeQ, l.faqCodeA),
                      (l.faqMultiQ, l.faqMultiA),
                      (null, l.helpMore),
                    ]),
                  ),
                  _Row(
                    icon: Icons.logout,
                    iconBg: const Color(0xFFFFDAD6),
                    iconFg: AppColors.danger,
                    title: l.signOut,
                    titleColor: AppColors.danger,
                    titleWeight: FontWeight.w600,
                    trailing: const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: AppColors.danger,
                    ),
                    onTap: () => _signOut(session),
                  ),
                  _Row(
                    icon: Icons.person_remove_outlined,
                    iconBg: const Color(0xFFFFDAD6),
                    iconFg: AppColors.danger,
                    title: 'Delete account',
                    titleColor: AppColors.danger,
                    onTap: () => launchUrl(
                      Uri.parse(_deleteAccountUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.madeForFamily,
                      style: AppText.labelSm.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                      ),
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

const _palette = [
  (AppColors.tertiaryFixed, AppColors.onTertiaryFixed),
  (AppColors.primaryFixed, AppColors.onPrimaryFixed),
  (AppColors.secondaryFixed, Color(0xFF002113)),
];

double _stackWidth(int members) {
  if (members == 0) return 0;
  final shown = members > 3 ? 4 : members;
  return (shown - 1) * 20.0 + 28;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text.toUpperCase(),
          style: AppText.labelMd.copyWith(
            color: AppColors.muted,
            letterSpacing: 0.6,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppText.labelSm.copyWith(
              color: AppColors.primary,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppShadows.sm,
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.surfaceLow,
              ),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.pill,
    this.pillBg,
    this.pillFg,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.iconBg = AppColors.surfaceContainer,
    this.iconFg = AppColors.text,
    this.titleColor = AppColors.text,
    this.titleWeight = FontWeight.w500,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final String? pill;
  final Color? pillBg;
  final Color? pillFg;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color iconBg;
  final Color iconFg;
  final Color titleColor;
  final FontWeight titleWeight;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            IconTile(icon: icon, bg: iconBg, fg: iconFg, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyMd.copyWith(
                      color: titleColor,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (pill != null) ...[
              Flexible(
                child: AppPill(
                  pill!,
                  bg: pillBg!,
                  fg: pillFg!,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: AppText.bodySm.copyWith(color: AppColors.muted),
                ),
              ),
            ?trailing,
            if (trailing == null && chevron && onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: _outlineVariant),
          ],
        ),
      ),
    ),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;
  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final controller = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
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
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.editProfile,
              style: AppText.headlineSm.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: l.profileNameLabel,
              controller: controller,
              icon: Icons.badge_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty || v.trim().length > 100
                  ? l.requiredField
                  : null,
            ),
            const SizedBox(height: 16),
            AppCta(
              label: l.saveChanges,
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(context, controller.text.trim());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final repository = context.read<AuthRepository>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.updatePassword(password.text);
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) {
        setState(() {
          busy = false;
          error = AppLocalizations.of(context)!.weakPassword;
        });
      }
    }
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
                l.changePassword,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l.newPassword,
                controller: password,
                obscureText: true,
                icon: Icons.lock_outline,
                validator: (v) =>
                    FormValidation.password(v ?? '') ? null : l.shortPassword,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: l.confirmPassword,
                controller: confirm,
                obscureText: true,
                icon: Icons.lock_outline,
                validator: (v) =>
                    FormValidation.confirmation(v ?? '', password.text)
                    ? null
                    : l.passwordMismatch,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: AppText.bodySm.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              AppCta(
                label: l.changePassword,
                icon: Icons.lock_reset,
                loading: busy,
                onPressed: submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet({required this.household, required this.l});
  final String household;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Container(
        padding: const EdgeInsetsDirectional.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.md,
          border: Border.all(color: const Color(0x99FFDAD6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDAD6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.power_settings_new,
                    size: 26,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.signOutTitle,
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                          children: [
                            TextSpan(text: l.signOutPre),
                            TextSpan(
                              text: household,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: l.signOutPost),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppCta(
                    label: l.cancel,
                    color: AppColors.surfaceContainer,
                    foreground: AppColors.text,
                    shadow: false,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCta(
                    label: l.signOut,
                    icon: Icons.logout,
                    color: AppColors.danger,
                    onPressed: () => Navigator.pop(context, true),
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
