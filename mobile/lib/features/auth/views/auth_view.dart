import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/form_validation.dart';
import '../repositories/auth_repository.dart';
import '../viewmodels/auth_view_model.dart';

class AuthView extends StatefulWidget {
  const AuthView({required this.mode, super.key});
  final String mode;
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  bool visible = false;
  bool bannerDismissed = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => AuthViewModel(context.read<AuthRepository>()),
    child: Builder(
      builder: (context) {
        final l = AppLocalizations.of(context)!;
        final vm = context.watch<AuthViewModel>();
        final registration = widget.mode == 'register';
        final reset = widget.mode == 'resetPassword';
        final forgot = widget.mode == 'forgotPassword';
        final title = registration
            ? l.register
            : reset
            ? l.resetPassword
            : forgot
            ? l.forgotPassword
            : l.login;
        final credentialError =
            vm.errorCode == 'invalid_credentials' ||
            vm.errorCode == 'email_not_confirmed';
        final error = switch (vm.errorCode) {
          'invalid_credentials' ||
          'email_not_confirmed' => l.invalidCredentials,
          'over_email_send_rate_limit' ||
          'over_request_rate_limit' => l.authRateLimit,
          'weak_password' => l.weakPassword,
          _ => l.authFailed,
        };
        final headline = registration
            ? l.createAccountTitle
            : reset || forgot
            ? title
            : l.welcomeBack;
        final subtitle = registration || reset || forgot
            ? l.accountSubtitle
            : l.signInSubtitle;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        headline: headline,
                        subtitle: subtitle,
                        tag: l.authBrandTag,
                      ),
                      if (!forgot && !reset)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 24),
                          child: _ModeSwitch(
                            registration: registration,
                            signIn: l.login,
                            create: l.register,
                            onChanged: vm.busy
                                ? null
                                : (value) => context.goNamed(
                                    value ? 'register' : 'login',
                                  ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsetsDirectional.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (vm.failed && !bannerDismissed) ...[
                                _ErrorBanner(
                                  title: credentialError
                                      ? l.invalidCredentialsTitle
                                      : l.authFailedTitle,
                                  message: error,
                                  dismissLabel: l.dismiss,
                                  onDismiss: () =>
                                      setState(() => bannerDismissed = true),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (registration) ...[
                                AppTextField(
                                  label: l.fullName,
                                  controller: _name,
                                  icon: Icons.badge_outlined,
                                  hint: l.fullNameHint,
                                  validator: (value) =>
                                      value == null ||
                                          value.trim().isEmpty ||
                                          value.trim().length > 100
                                      ? l.requiredField
                                      : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!reset) ...[
                                AppTextField(
                                  label: l.email,
                                  controller: _email,
                                  icon: Icons.mail_outline,
                                  hint: l.emailHint,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) =>
                                      FormValidation.email(value ?? '')
                                      ? null
                                      : l.invalidEmail,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!forgot) ...[
                                AppTextField(
                                  label: l.password,
                                  controller: _password,
                                  obscureText: !visible,
                                  icon: Icons.lock_outline,
                                  hint: '••••••••••••',
                                  labelAction:
                                      !registration && !reset && !forgot
                                      ? InkWell(
                                          onTap: () =>
                                              context.goNamed('forgotPassword'),
                                          child: Container(
                                            height: 28,
                                            alignment: Alignment.center,
                                            padding:
                                                const EdgeInsetsDirectional.symmetric(
                                                  horizontal: 4,
                                                ),
                                            child: Text(
                                              l.forgotPasswordLink,
                                              style: AppText.labelSm.copyWith(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                  suffix: IconButton(
                                    tooltip: l.password,
                                    onPressed: () =>
                                        setState(() => visible = !visible),
                                    icon: Icon(
                                      visible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: const Color(0xFF747686),
                                    ),
                                  ),
                                  validator: (value) => registration || reset
                                      ? (FormValidation.password(value ?? '')
                                            ? null
                                            : l.shortPassword)
                                      : ((value?.isNotEmpty ?? false)
                                            ? null
                                            : l.requiredField),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (registration || reset) ...[
                                AppTextField(
                                  label: l.confirmPassword,
                                  controller: _confirm,
                                  obscureText: true,
                                  icon: Icons.lock_outline,
                                  hint: '••••••••••••',
                                  validator: (value) =>
                                      FormValidation.confirmation(
                                        value ?? '',
                                        _password.text,
                                      )
                                      ? null
                                      : l.passwordMismatch,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (vm.succeeded)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    bottom: 16,
                                  ),
                                  child: Text(
                                    forgot
                                        ? l.neutralReset
                                        : reset
                                        ? l.passwordUpdated
                                        : l.authSuccess,
                                    style: AppText.bodySm.copyWith(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: 8,
                                ),
                                child: _SubmitButton(
                                  key: const Key('auth-submit'),
                                  label: forgot ? l.sendResetLink : title,
                                  icon: registration
                                      ? Icons.person_add_alt
                                      : forgot
                                      ? Icons.mail_outline
                                      : reset
                                      ? Icons.lock_reset
                                      : Icons.login,
                                  loading: vm.busy,
                                  onPressed: () async {
                                    if (!_form.currentState!.validate()) return;
                                    setState(() => bannerDismissed = false);
                                    final session = context
                                        .read<SessionViewModel>();
                                    await vm.submit(
                                      widget.mode,
                                      _email.text,
                                      _password.text,
                                      _name.text,
                                    );
                                    if (context.mounted &&
                                        vm.errorCode == 'email_not_confirmed') {
                                      session.awaitVerification(_email.text);
                                      context.goNamed('verifyEmail');
                                      return;
                                    }
                                    if (!context.mounted || !vm.succeeded) {
                                      return;
                                    }
                                    if (registration && session.user == null) {
                                      session.awaitVerification(_email.text);
                                    }
                                    if (reset) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(l.passwordUpdated),
                                            ),
                                          );
                                      session.completePasswordRecovery();
                                    }
                                  },
                                ),
                              ),
                              if (!reset)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: forgot
                                      ? Center(
                                          child: _TextAction(
                                            label: l.backToLogin,
                                            onTap: () =>
                                                context.goNamed('login'),
                                          ),
                                        )
                                      : Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              registration
                                                  ? l.onboardHaveAccount
                                                  : l.noAccount,
                                              style: AppText.bodySm.copyWith(
                                                color: AppColors.muted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _TextAction(
                                              label: registration
                                                  ? l.login
                                                  : l.register,
                                              onTap: () => context.goNamed(
                                                registration
                                                    ? 'login'
                                                    : 'register',
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ConnectionNote(
                        title: l.householdConnection,
                        step: l.householdConnectionStep,
                        body: l.householdConnectionDescription,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.headline,
    required this.subtitle,
    required this.tag,
  });
  final String headline;
  final String subtitle;
  final String tag;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 16, bottom: 24),
    child: Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.sm,
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      AppColors.primary.withAlpha(26),
                      Colors.transparent,
                      AppColors.secondary.withAlpha(38),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.md,
                  ),
                  child: const Icon(
                    Icons.cottage,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.sm,
                  ),
                  child: const Icon(
                    Icons.stars_outlined,
                    size: 14,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              'HomeCircle',
              style: AppText.headlineSm.copyWith(
                color: AppColors.primary,
                letterSpacing: -0.45,
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                tag,
                style: AppText.labelSm.copyWith(
                  color: AppColors.onPrimaryFixed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: AppText.headlineLg.copyWith(
            color: AppColors.text,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.registration,
    required this.signIn,
    required this.create,
    required this.onChanged,
  });
  final bool registration;
  final String signIn;
  final String create;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppShadows.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeTab(
            label: signIn,
            icon: Icons.login,
            active: !registration,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _ModeTab(
            label: create,
            icon: Icons.person_add_alt,
            active: registration,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ),
      ],
    ),
  );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? AppShadows.sm : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelLg.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
  });
  final String title;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFDAD6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(top: 2),
          child: Icon(Icons.error_outline, size: 20, color: AppColors.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.labelMd.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(4, -4),
          child: IconButton(
            tooltip: dismissLabel,
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppShadows.sm,
    ),
    child: Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          height: 48,
          child: loading
              ? const Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelLg.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 4,
        vertical: 11,
      ),
      child: Text(
        label,
        style: AppText.labelSm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ConnectionNote extends StatelessWidget {
  const _ConnectionNote({
    required this.title,
    required this.step,
    required this.body,
  });
  final String title;
  final String step;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.sm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsetsDirectional.only(top: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.diversity_1_outlined,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    title,
                    style: AppText.labelMd.copyWith(color: AppColors.text),
                  ),
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      step,
                      style: AppText.labelSm.copyWith(
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
