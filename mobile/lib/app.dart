import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_runtime.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class HomeCircleApp extends StatefulWidget {
  const HomeCircleApp({required this.runtime, super.key});
  final AppRuntime runtime;
  @override
  State<HomeCircleApp> createState() => _HomeCircleAppState();
}

class _HomeCircleAppState extends State<HomeCircleApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  int _scopeRevision = 0;

  void _sessionChanged() {
    final revision = widget.runtime.session.scopeRevision;
    if (revision == _scopeRevision) return;
    _scopeRevision = revision;
    widget.runtime.diagnostics.reset();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createRouter(widget.runtime.session);
    widget.runtime.session.addListener(_sessionChanged);
    unawaited(widget.runtime.session.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !widget.runtime.session.restoring) {
      unawaited(widget.runtime.session.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.runtime.session.removeListener(_sessionChanged);
    _router.dispose();
    widget.runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: widget.runtime.auth),
      Provider.value(value: widget.runtime.households),
      Provider.value(value: widget.runtime.store),
      ChangeNotifierProvider.value(value: widget.runtime.session),
      ChangeNotifierProvider.value(value: widget.runtime.network),
      ChangeNotifierProvider.value(value: widget.runtime.diagnostics),
      ChangeNotifierProvider.value(value: widget.runtime.inventory),
      ChangeNotifierProvider.value(value: widget.runtime.tasks),
      ChangeNotifierProvider.value(value: widget.runtime.shopping),
    ],
    child: MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      theme: AppTheme.light,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class ConfigurationApp extends StatelessWidget {
  const ConfigurationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(title: Text(l.configurationTitle)),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Text(
                  l.configurationMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
