#!/usr/bin/env bash
# Opens the release APK and saves a screenshot plus logcat, then runs the
# integration tests on the emulator. Everything lands in emulator-report/.
set -x
out=emulator-report
mkdir -p "$out"
pkg=com.gfuentes.dictation_app
shot() { adb exec-out screencap -p > "$out/$1.png"; }

adb logcat -c
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1
sleep 15
shot 01-home
adb shell dumpsys activity activities | grep -i "$pkg" | head -5 > "$out/activity.txt"
adb shell pidof "$pkg" > "$out/pid.txt" || echo "NOT RUNNING" > "$out/pid.txt"
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml "$out/01-home.xml"
adb logcat -d > "$out/logcat-release.txt"
adb logcat -d -b crash > "$out/crash-release.txt"
adb uninstall "$pkg"

# Full flow with the real voice and storage plugins.
adb logcat -c
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart 2>&1 | tee "$out/integration.txt"
status=${PIPESTATUS[0]}
adb logcat -d > "$out/logcat-integration.txt"
exit $status
