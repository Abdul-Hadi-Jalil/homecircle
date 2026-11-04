import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../repositories/auth_repository.dart';
import '../viewmodels/auth_view_model.dart';

class AuthNoticeView extends StatefulWidget {
  const AuthNoticeView({this.invalidLink = false, super.key});
  final bool invalidLink;
  @override
  State<AuthNoticeView> createState() => _AuthNoticeViewState();
}

class _AuthNoticeViewState extends State<AuthNoticeView> {
  Timer? timer;
  late final AuthViewModel vm;
  @override
  void initState() {
    super.initState();
    vm = AuthViewModel(context.read<AuthRepository>());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final session = context.watch<SessionViewModel>();
    final waiting = vm.resendAvailableAt?.isAfter(DateTime.now()) ?? false;
    return ChangeNotifierProvider.value(
      value: vm,
      child: Builder(
        builder: (context) {
          context.watch<AuthViewModel>();
          return AppScaffold(
            title: widget.invalidLink ? l.authFailed : l.checkEmail,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Icon(
                        widget.invalidLink
                            ? Icons.link_off
                            : Icons.mark_email_unread_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.invalidLink
                            ? l.authLinkError
                            : l.verificationMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!widget.invalidLink && session.pendingEmail != null)
                        AppPrimaryButton(
                          label: l.resendVerification,
                          loading: vm.busy,
                          onPressed: waiting
                              ? null
                              : () => vm.resend(session.pendingEmail!),
                        ),
                      if (waiting)
                        Padding(
                          padding: const EdgeInsetsDirectional.all(8),
                          child: Text(l.resendWait),
                        ),
                      if (vm.failed) AppErrorState(message: l.authFailed),
                      if (vm.succeeded) Text(l.authSuccess),
                      TextButton(
                        onPressed: () {
                          session.dismissAuthNotice();
                          context.goNamed('login');
                        },
                        child: Text(l.backToLogin),
                      ),
                      if (widget.invalidLink)
                        TextButton(
                          onPressed: () {
                            session.dismissAuthNotice();
                            context.goNamed('forgotPassword');
                          },
                          child: Text(l.forgotPassword),
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
}
