import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/generated/app_localizations.dart';
import '../network/network_status.dart';
import '../theme/app_theme.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    child: loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.icon,
    this.hint,
    this.suffix,
    this.labelAction,
    this.trailing,
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? icon;
  final String? hint;

  /// Widget shown inside the field at its trailing edge (eg. a visibility toggle).
  final Widget? suffix;

  /// Small action shown opposite the label (eg. "Forgot Password?").
  final Widget? labelAction;

  /// Non-interactive indicator drawn inside the field (eg. a verified icon).
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppText.labelMd.copyWith(color: AppColors.muted),
              ),
            ),
            ?labelAction,
          ],
        ),
      ),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: !obscureText,
        validator: validator,
        keyboardType: keyboardType,
        style: AppText.bodyMd.copyWith(color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                  child: Icon(icon, size: 20, color: const Color(0xFF747686)),
                ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 20,
          ),
          suffixIcon: suffix ?? trailing,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
        ),
      ),
    ],
  );
}

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline),
      const SizedBox(height: 8),
      Text(message),
      if (onRetry != null)
        TextButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context)!.retry),
        ),
    ],
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.bottomNavigationBar,
    this.appBar,
    this.floatingActionButton,
    super.key,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;

  /// Replaces the default app bar (used by screens that follow the brand bar).
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar ?? AppBar(title: Text(title), actions: actions),
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      child: Column(
        children: [
          if (context.watch<NetworkStatus>().offline)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(8),
                  child: Text(
                    AppLocalizations.of(context)!.offline,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    ),
  );
}
