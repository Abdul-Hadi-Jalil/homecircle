import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_runtime.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/viewmodels/notifications_viewmodel.dart';

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
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  void _notificationsChanged() {
    final vm = widget.runtime.notifications, session = widget.runtime.session;
    final target = vm.takeDestination(),
        actor = session.user?.id,
        home = session.activeHousehold?.id;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            vm.ready &&
            session.user?.id == actor &&
            session.activeHousehold?.id == home) {
          _router.goNamed(
            target.route,
            pathParameters: {if (target.id != null) 'id': target.id!},
          );
        }
      });
    }
    if (target != null) WidgetsBinding.instance.ensureVisualUpdate();
  }

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
    widget.runtime.notifications.addListener(_notificationsChanged);
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
    widget.runtime.notifications.removeListener(_notificationsChanged);
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
      ChangeNotifierProvider.value(value: widget.runtime.chat),
      ChangeNotifierProvider.value(value: widget.runtime.dashboard),
      ChangeNotifierProvider.value(value: widget.runtime.activity),
      ChangeNotifierProvider.value(value: widget.runtime.notifications),
    ],
    child: MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      builder: (context, child) => Consumer<NotificationsViewModel>(
        builder: (context, vm, _) {
          if (!vm.banner || !vm.ready) return child!;
          final l = AppLocalizations.of(context)!,
              actor = vm.user,
              id = vm.foregroundId;
          void dismiss() {
            vm.banner = false;
            vm.emit();
          }

          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: MaterialBanner(
                  content: Text(l.hubForeground),
                  leading: const Icon(Icons.notifications_active_outlined),
                  actions: [
                    TextButton(
                      onPressed: () {
                        if (!vm.ready || vm.user != actor) return;
                        dismiss();
                        if (id != null) {
                          vm.acceptPush({'notification_id': id});
                        } else {
                          _router.pushNamed('notifications');
                        }
                      },
                      child: Text(l.hubOpen),
                    ),
                    TextButton(onPressed: dismiss, child: Text(l.hubDismiss)),
                  ],
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child!,
                ),
              ),
            ],
          );
        },
      ),
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
