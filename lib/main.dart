import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/inkora_app.dart';
import 'app/licenses.dart';

void main() {
  registerInkoraLicenses();
  runApp(const ProviderScope(child: InkoraApp()));
}
