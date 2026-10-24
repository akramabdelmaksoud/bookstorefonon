# Bookstore POS (Flutter + Supabase)

## Setup
1. Supabase SQL editor → run `supabase/schema.sql`.
2. Authentication → create users (cashiers/owner). Promote the owner:
   `update profiles set role = 'admin' where id = '<auth uid>';`
3. Run (replace with your project's values; never commit them):

```bash
flutter run --dart-define=SUPABASE_URL=https://YOURREF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=STORE_NAME="My Bookstore" --dart-define=CURRENCY=EGP
```

## Structure
```
lib/
  core/         config (Env), theme, formatters
  domain/       entities + repository interfaces (no Flutter/Supabase imports)
  data/         Supabase repository implementations
  services/     PrinterService (Bluetooth ESC/POS)
  presentation/ providers (Riverpod), auth, cashier, admin
supabase/schema.sql   tables, RLS, complete_sale() and adjust_stock() RPCs
```

Cashiers land on the POS screen, admins on the dashboard (role from `profiles`).

## Local run
`env.json` (git-ignored) holds the URL and publishable key:

```bash
flutter run --dart-define-from-file=env.json
```
