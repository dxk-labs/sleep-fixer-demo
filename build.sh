#!/bin/bash

# Download and setup Flutter
echo "Setting up Flutter..."
curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar xf flutter.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

# Verify Flutter is available
echo "Flutter version:"
flutter --version

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build web app
echo "Building web app..."
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false

echo "Build completed!" 