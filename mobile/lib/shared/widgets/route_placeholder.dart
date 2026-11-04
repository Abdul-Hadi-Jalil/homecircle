import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/widgets/app_widgets.dart';

class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: title,
    body: AppEmptyState(message: AppLocalizations.of(context)!.placeholder),
  );
}
