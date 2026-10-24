/// Supplied at build time so secrets never live in source control:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// (The anon key is public by design; security comes from RLS in supabase/schema.sql.)
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const storeName = String.fromEnvironment('STORE_NAME', defaultValue: 'My Bookstore');
  static const currency = String.fromEnvironment('CURRENCY', defaultValue: 'EGP');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
