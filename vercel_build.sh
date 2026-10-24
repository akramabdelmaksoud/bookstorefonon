#!/bin/bash
# Builds the Flutter web app on Vercel. Needs env vars SUPABASE_URL and SUPABASE_ANON_KEY
# (set in Vercel > Project > Settings > Environment Variables; use the *publishable* key only).
set -e
if [ ! -d flutter ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git
fi
export PATH="$PWD/flutter/bin:$PATH"
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=STORE_NAME="${STORE_NAME:-My Bookstore}" \
  --dart-define=CURRENCY="${CURRENCY:-EGP}"
