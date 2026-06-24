import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Baked in at compile time via --dart-define (Netlify build).
  // Falls back to .env for local development.
  static const _compiledUrl = String.fromEnvironment('SUPABASE_URL');
  static const _compiledKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static Future<void> initialize() async {
    String url = _compiledUrl;
    String key = _compiledKey;

    if (url.isEmpty || key.isEmpty) {
      try {
        await dotenv.load(fileName: '.env');
        url = dotenv.env['SUPABASE_URL'] ?? '';
        key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
      } catch (_) {}
    }

    if (kDebugMode || url.isEmpty || key.isEmpty) {
      debugPrint('[SupabaseConfig] URL=$url key=${key.isEmpty ? "(vacía)" : "(ok)"}');
    }
    await Supabase.initialize(url: url, publishableKey: key);
  }
}

SupabaseClient get supabase => Supabase.instance.client;
