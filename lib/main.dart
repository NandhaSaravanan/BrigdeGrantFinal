import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

import 'src/app.dart';
import 'src/config.dart';
import 'src/repository.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  final problem = config.problem;
  if (problem != null) {
    runApp(ConfigErrorApp(problem: problem));
    return;
  }
  // No sign-in: the client only reads the public views with the
  // publishable key, so token refresh is unnecessary.
  final client = SupabaseClient(
    config.supabaseUrl,
    config.supabaseKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  runApp(BridgeGrantApp(repository: SupabaseGrantsRepository(client)));
}
