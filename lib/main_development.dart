import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/inkora_app.dart';
import 'app/licenses.dart';
import 'features/connection/application/session_controller.dart';
import 'features/connection/data/development_login.dart';
import 'features/connection/domain/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerInkoraLicenses();
  StartupLogin? startup;
  if (kDebugMode && Platform.isAndroid) {
    final directory = await getApplicationSupportDirectory();
    startup = await takeDevelopmentLogin(
      File('${directory.path}/development-login.json'),
    );
  }
  runApp(
    ProviderScope(
      overrides: [startupLoginProvider.overrideWithValue(startup)],
      child: const InkoraApp(),
    ),
  );
}
