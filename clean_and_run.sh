#!/bin/bash

echo "========================================"
echo " Cleaning and Restarting Flutter App"
echo "========================================"
echo ""

echo "Step 1: Cleaning Flutter build cache..."
flutter clean
if [ $? -ne 0 ]; then
    echo "ERROR: Flutter clean failed"
    exit 1
fi
echo "✅ Clean complete"
echo ""

echo "Step 2: Removing build directory..."
rm -rf build/
echo "✅ Build directory removed"
echo ""

echo "Step 3: Getting dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "ERROR: Flutter pub get failed"
    exit 1
fi
echo "✅ Dependencies updated"
echo ""

echo "Step 4: Starting app with HTML renderer..."
echo ""
echo "========================================"
echo " App is starting..."
echo " Press Ctrl+C to stop"
echo "========================================"
echo ""

flutter run -d chrome --web-renderer html
