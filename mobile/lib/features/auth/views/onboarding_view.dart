import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final controller = PageController();
  int index = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish(String destination) async {
    await context.read<SessionViewModel>().completeOnboarding();
    if (mounted) context.goNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final titles = [l.tagline, l.onboardTeamTitle, l.onboardSyncTitle];
    final descriptions = [l.onboardItems, l.onboardTeam, l.onboardSync];
    final icons = [
      Icons.inventory_2_outlined,
      Icons.checklist_rounded,
      Icons.forum_outlined,
    ];
    return AppScaffold(
      title: l.appName,
      actions: [
        TextButton(onPressed: () => finish('welcome'), child: Text(l.skip)),
      ],
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: 3,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, page) => SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsetsDirectional.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        icons[page],
                        size: 96,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      titles[page],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      descriptions[page],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (page) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsetsDirectional.all(4),
                height: 8,
                width: page == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: page == index ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPrimaryButton(
                  label: index == 2 ? l.getStarted : l.next,
                  onPressed: () {
                    if (index == 2) {
                      finish('register');
                    } else {
                      controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
                TextButton(
                  onPressed: () => finish('login'),
                  child: Text(l.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
