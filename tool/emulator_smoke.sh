#!/usr/bin/env bash
# Installs the release APK, opens it, taps through the screens that need no
# network, and saves screenshots plus logcat to emulator-report/.
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
adb logcat -d > "$out/logcat.txt"
adb logcat -d -b crash > "$out/crash.txt"
exit 0
