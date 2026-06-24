import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    if (kDebugMode || url.isEmpty || key.isEmpty) {
      debugPrint('[SupabaseConfig] URL=$url key=${key.isEmpty ? "(vacía)" : "(ok)"}');
    }
    await Supabase.initialize(url: url, anonKey: key);
  }
}

SupabaseClient get supabase => Supabase.instance.client;
