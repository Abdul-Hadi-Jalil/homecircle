import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    runApp(const ConfigurationApp());
    return;
  }
  try {
    final runtime = await AppRuntime.initialize(config);
    runApp(HomeCircleApp(runtime: runtime));
  } on Object {
    // Never print initialization exceptions: SDK errors may include sensitive values.
    runApp(const ConfigurationApp());
  }
}
