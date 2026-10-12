#!/bin/bash
# Builds Tomoporo.app and installs it to /Applications so Spotlight can find it.
set -e
cd "$(dirname "$0")"

APP="Tomoporo.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/tomoporo" main.swift
cp Info.plist "$APP/Contents/Info.plist"

if [ "$1" = "--install" ]; then
    rm -rf "/Applications/$APP"
    cp -R "$APP" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP"
    echo "Installed to /Applications/$APP — search 'Tomoporo' in Spotlight."
else
    echo "Built $APP — run with: open $APP (or ./build.sh --install to install to /Applications)"
fi
