/// Build-time configuration supplied with `--dart-define`.
///
/// Only the Supabase project URL and the publishable (anon) key belong here.
/// Never pass a service-role key to a client build.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String supabaseUrl;
  final String supabaseKey;

  /// Returns a human-readable problem with the configuration, or null.
  String? get problem {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      return 'SUPABASE_URL and SUPABASE_ANON_KEY must be provided with '
          '--dart-define.';
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL is not a valid URL.';
    }
    if (looksLikeServiceRoleKey(supabaseKey)) {
      return 'The supplied key appears to be a service-role/secret key. '
          'Use the publishable (anon) key instead.';
    }
    return null;
  }
}

/// Detects secret keys so a misconfigured build refuses to run with one.
bool looksLikeServiceRoleKey(String key) {
  if (key.startsWith('sb_secret_')) return true;
  final parts = key.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = String.fromCharCodes(
      _base64UrlDecode(parts[1]),
    ).replaceAll(' ', '');
    return payload.contains('"role":"service_role"');
  } catch (_) {
    return false;
  }
}

List<int> _base64UrlDecode(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return Uri.parse('data:;base64,$normalized').data!.contentAsBytes();
}
