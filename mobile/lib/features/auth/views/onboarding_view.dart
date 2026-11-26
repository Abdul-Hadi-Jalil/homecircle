import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../household/viewmodels/session_view_model.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int index = 0;

  Future<void> finish(String destination) async {
    await context.read<SessionViewModel>().completeOnboarding();
    if (mounted) context.goNamed(destination);
  }

  void go(int step) => setState(() => index = step.clamp(0, 2));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final titles = [l.tagline, l.onboardTeamTitle, l.onboardSyncTitle];
    final descriptions = [l.onboardItems, l.onboardTeam, l.onboardSync];
    final tabs = [
      (Icons.inventory_2_outlined, l.onboardTab1),
      (Icons.checklist_rtl, l.onboardTab2),
      (Icons.group_outlined, l.onboardTab3),
    ];
    final last = index == 2;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -200) go(index + 1);
            if (v > 200) go(index - 1);
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        tag: l.onboardBrandTag,
                        skip: l.skip,
                        onSkip: () => finish('login'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: _StepTab(
                                icon: tabs[i].$1,
                                label: tabs[i].$2,
                                active: i == index,
                                onTap: () => go(i),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Hero(step: index, l: l),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.onboardStepCounter(index + 1).toUpperCase(),
                              style: AppText.labelSm.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 0.55,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              titles[index],
                              style: AppText.headlineLg.copyWith(
                                color: AppColors.text,
                                letterSpacing: -0.65,
                                height: 1.375,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              descriptions[index],
                              style: AppText.bodyLg.copyWith(
                                color: AppColors.muted,
                                height: 1.625,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            GestureDetector(
                              onTap: () => go(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width: i == index ? 28 : 8,
                                decoration: BoxDecoration(
                                  color: i == index
                                      ? AppColors.primary
                                      : AppColors.surfaceHighest,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CtaButton(
                      label: last ? l.getStarted : l.next,
                      icon: last ? Icons.check : Icons.arrow_forward,
                      onPressed: () =>
                          last ? finish('register') : go(index + 1),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: 4,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l.onboardHaveAccount,
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          InkWell(
                            onTap: () => finish('login'),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                6,
                                4,
                                0,
                                4,
                              ),
                              child: Text(
                                l.onboardSignIn,
                                style: AppText.labelLg.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tag, required this.skip, required this.onSkip});
  final String tag;
  final String skip;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.sm,
              ),
              child: const Icon(Icons.cottage, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HomeCircle',
                  style: AppText.headlineSm.copyWith(
                    color: AppColors.text,
                    height: 1,
                    letterSpacing: -0.45,
                  ),
                ),
                Text(
                  tag,
                  style: AppText.labelSm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
        Material(
          color: AppColors.surfaceLow,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onSkip,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Text(
                skip,
                style: AppText.labelMd.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.all(4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? AppShadows.sm : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelSm.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppShadows.md,
    ),
    child: Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppText.labelLg.copyWith(color: Colors.white)),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.step, required this.l});
  final int step;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 220),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.sm,
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -24,
          bottom: -24,
          child: _Blob(
            size: 144,
            color: AppColors.surfaceHighest.withAlpha(153),
          ),
        ),
        Positioned(
          left: -24,
          top: -24,
          child: _Blob(
            size: 128,
            color: AppColors.secondaryContainer.withAlpha(77),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(step),
                child: switch (step) {
                  0 => _OrganizeGraphic(l: l),
                  1 => _ShareGraphic(l: l),
                  _ => _ConnectGraphic(l: l),
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// White demo card (max 280dp) with floating badges anchored to its stage.
class _Stage extends StatelessWidget {
  const _Stage({required this.card, this.badges = const []});
  final Widget card;
  final List<Widget> badges;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: card,
      ),
      ...badges,
    ],
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.dot,
    required this.title,
    required this.trailing,
    required this.children,
  });
  final Color dot;
  final String title;
  final Widget trailing;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.sm,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.only(bottom: 4),
          margin: const EdgeInsetsDirectional.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.surfaceContainer),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: AppText.labelMd.copyWith(color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(9999),
    ),
    child: Text(text, style: AppText.labelSm.copyWith(color: fg)),
  );
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.trailing,
  });
  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(8),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: AppText.bodyMd.copyWith(color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _FloatBadge extends StatelessWidget {
  const _FloatBadge({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.text,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
  final Color bg;
  final Color fg;
  final IconData icon;
  final String text;
  final double? top, bottom, left, right;
  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(text, style: AppText.labelSm.copyWith(color: fg)),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.letter, {required this.bg, required this.fg});
  final String letter;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Text(
      letter,
      style: AppText.labelSm.copyWith(fontSize: 10, color: fg, height: 1),
    ),
  );
}

class _OrganizeGraphic extends StatelessWidget {
  const _OrganizeGraphic({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => _Stage(
    card: _DemoCard(
      dot: AppColors.secondary,
      title: l.demoPantry,
      trailing: _Pill(
        l.demoRestocked,
        bg: AppColors.secondaryContainer,
        fg: AppColors.onSecondaryContainer,
      ),
      children: [
        _DemoRow(
          icon: Icons.local_cafe_outlined,
          iconColor: AppColors.primary,
          text: l.demoOatMilk,
          trailing: const Icon(
            Icons.check_circle,
            size: 18,
            color: AppColors.secondary,
          ),
        ),
        _DemoRow(
          icon: Icons.local_laundry_service_outlined,
          iconColor: AppColors.tertiary,
          text: l.demoDetergent,
          trailing: _Pill(
            l.demoTwoLeft,
            bg: AppColors.tertiaryFixed,
            fg: AppColors.onTertiaryFixed,
          ),
        ),
      ],
    ),
    badges: [
      _FloatBadge(
        top: -12,
        right: -8,
        bg: AppColors.primary,
        fg: Colors.white,
        icon: Icons.auto_awesome,
        text: l.demoSmartAlert,
      ),
      Positioned(
        bottom: -12,
        left: -8,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: AppShadows.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Avatar(
                'M',
                bg: AppColors.primaryContainer,
                fg: Color(0xFFF5F3FF),
              ),
              const SizedBox(width: 6),
              Text(
                l.demoMomUpdated,
                style: AppText.labelSm.copyWith(color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ShareGraphic extends StatelessWidget {
  const _ShareGraphic({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => _Stage(
    card: _DemoCard(
      dot: AppColors.primary,
      title: l.demoChores,
      trailing: _Pill(
        l.demoFairSplit,
        bg: AppColors.primaryFixed,
        fg: AppColors.onPrimaryFixed,
      ),
      children: [
        _DemoRow(
          icon: Icons.recycling,
          iconColor: AppColors.primary,
          text: l.demoBins,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Avatar(
                'L',
                bg: AppColors.secondaryFixed,
                fg: Color(0xFF002113),
              ),
              const SizedBox(width: 4),
              Text(
                l.demoDone,
                style: AppText.labelSm.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
        ),
        _DemoRow(
          icon: Icons.water_drop_outlined,
          iconColor: AppColors.primaryContainer,
          text: l.demoPlants,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Avatar(
                'D',
                bg: AppColors.tertiaryFixed,
                fg: AppColors.onTertiaryFixed,
              ),
              const SizedBox(width: 4),
              Text(
                l.demoToday,
                style: AppText.labelSm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
    badges: [
      _FloatBadge(
        top: -12,
        left: -8,
        bg: AppColors.secondary,
        fg: Colors.white,
        icon: Icons.volunteer_activism_outlined,
        text: l.demoNoNagging,
      ),
    ],
  );
}

class _ConnectGraphic extends StatelessWidget {
  const _ConnectGraphic({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => _Stage(
    card: _DemoCard(
      dot: AppColors.secondary,
      title: l.demoStream,
      trailing: const SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      children: [
        _Bubble(
          bg: AppColors.surfaceHigh,
          name: l.demoDadMarket,
          nameColor: AppColors.primary,
          time: l.demoTwoMin,
          timeColor: AppColors.muted,
          body: l.demoSourdough,
          bodyColor: AppColors.text,
        ),
        _Bubble(
          bg: AppColors.primary,
          name: l.demoEmma,
          nameColor: Colors.white,
          time: l.demoJustNow,
          timeColor: Colors.white.withAlpha(204),
          body: l.demoAvocados,
          bodyColor: Colors.white,
        ),
      ],
    ),
    badges: [
      _FloatBadge(
        bottom: -12,
        right: -8,
        bg: AppColors.primaryContainer,
        fg: const Color(0xFFF5F3FF),
        icon: Icons.sync,
        text: l.demoInstantSync,
      ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.bg,
    required this.name,
    required this.nameColor,
    required this.time,
    required this.timeColor,
    required this.body,
    required this.bodyColor,
  });
  final Color bg, nameColor, timeColor, bodyColor;
  final String name, time, body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: AppText.labelSm.copyWith(color: nameColor)),
            Text(
              time,
              style: AppText.labelSm.copyWith(
                color: timeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(body, style: AppText.bodySm.copyWith(color: bodyColor)),
      ],
    ),
  );
}
