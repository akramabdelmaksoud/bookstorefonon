/// Supplied at build time so secrets never live in source control:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// Defaults point at the production project; the publishable key is public by design.
/// (The anon key is public by design; security comes from RLS in supabase/schema.sql.)
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://orktjikoruvoqxjzgncb.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_jXA06711bciVQP_mVbid3Q_pkF2o3zR');
  static const storeName = String.fromEnvironment('STORE_NAME', defaultValue: 'My Bookstore');
  static const currency = String.fromEnvironment('CURRENCY', defaultValue: 'EGP');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
