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
        final error = switch (vm.errorCode) {
          'invalid_credentials' ||
          'email_not_confirmed' => l.invalidCredentials,
          'over_email_send_rate_limit' ||
          'over_request_rate_limit' => l.authRateLimit,
          'weak_password' => l.weakPassword,
          _ => l.authFailed,
        };
        return AppScaffold(
          title: l.appName,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.home_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      registration
                          ? l.createAccountTitle
                          : reset || forgot
                          ? title
                          : l.welcomeBack,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registration
                          ? l.accountSubtitle
                          : reset || forgot
                          ? l.accountSubtitle
                          : l.signInSubtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (!forgot && !reset)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 24),
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(l.login),
                              icon: const Icon(Icons.login),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(l.register),
                              icon: const Icon(Icons.person_add_alt),
                            ),
                          ],
                          selected: {registration},
                          onSelectionChanged: vm.busy
                              ? null
                              : (value) => context.goNamed(
                                  value.first ? 'register' : 'login',
                                ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(24),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (vm.failed)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    bottom: 16,
                                  ),
                                  child: AppErrorState(message: error),
                                ),
                              if (registration) ...[
                                AppTextField(
                                  label: l.fullName,
                                  controller: _name,
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
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) =>
                                      FormValidation.email(value ?? '')
                                      ? null
                                      : l.invalidEmail,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!forgot) ...[
                                TextFormField(
                                  controller: _password,
                                  obscureText: !visible,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  validator: (value) => registration || reset
                                      ? (FormValidation.password(value ?? '')
                                            ? null
                                            : l.shortPassword)
                                      : ((value?.isNotEmpty ?? false)
                                            ? null
                                            : l.requiredField),
                                  decoration: InputDecoration(
                                    labelText: l.password,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: l.password,
                                      onPressed: () =>
                                          setState(() => visible = !visible),
                                      icon: Icon(
                                        visible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (registration || reset) ...[
                                AppTextField(
                                  label: l.confirmPassword,
                                  controller: _confirm,
                                  obscureText: true,
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
                                  ),
                                ),
                              AppPrimaryButton(
                                label: forgot ? l.sendResetLink : title,
                                loading: vm.busy,
                                onPressed: () async {
                                  if (!_form.currentState!.validate()) return;
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
                                  if (!context.mounted || !vm.succeeded) return;
                                  if (registration && session.user == null) {
                                    session.awaitVerification(_email.text);
                                  }
                                  if (reset) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l.passwordUpdated),
                                      ),
                                    );
                                    session.completePasswordRecovery();
                                  }
                                },
                              ),
                              if (!registration && !forgot && !reset)
                                TextButton(
                                  onPressed: () =>
                                      context.goNamed('forgotPassword'),
                                  child: Text(l.forgotPassword),
                                ),
                              if (forgot)
                                TextButton(
                                  onPressed: () => context.goNamed('login'),
                                  child: Text(l.backToLogin),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: AppColors.lightBlue,
                      child: ListTile(
                        leading: const Icon(
                          Icons.diversity_1_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(l.householdConnection),
                        subtitle: Text(l.householdConnectionDescription),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
