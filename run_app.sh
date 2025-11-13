#!/bin/bash

echo "=========================================="
echo "🚀 SeaYou App - Build & Run"
echo "=========================================="
echo ""

echo "📍 Step 1: Cleaning project..."
flutter clean
rm -rf android/.gradle
rm -rf android/app/build
rm -rf build
echo "✅ Clean complete!"
echo ""

echo "📦 Step 2: Getting dependencies..."
flutter pub get
echo "✅ Dependencies installed!"
echo ""

echo "🔍 Step 3: Checking devices..."
flutter devices
echo ""

echo "🏗️ Step 4: Building and running app..."
echo "⏱️ This may take 5-10 minutes on first build..."
echo ""

flutter run

echo ""
echo "=========================================="
echo "✅ Done!"
echo "=========================================="
