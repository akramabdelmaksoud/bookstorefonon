#!/bin/bash
# Builds the Flutter web app on Vercel. Supabase URL + publishable key default to the values in lib/core/config/env.dart.
set -e
if [ ! -d flutter ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git
fi
export PATH="$PWD/flutter/bin:$PATH"
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=STORE_NAME="${STORE_NAME:-My Bookstore}" \
  --dart-define=CURRENCY="${CURRENCY:-EGP}"
