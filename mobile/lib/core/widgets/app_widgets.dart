import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/generated/app_localizations.dart';
import '../network/network_status.dart';

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
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    enableSuggestions: !obscureText,
    autocorrect: !obscureText,
    validator: validator,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
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
    super.key,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    bottomNavigationBar: bottomNavigationBar,
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
