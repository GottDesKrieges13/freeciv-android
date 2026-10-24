#!/bin/bash
# Monta o projeto Android com as bibliotecas e os dados do jogo e gera o APK de debug.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:?defina PREFIX}"
NDK="${ANDROID_NDK_HOME:?defina ANDROID_NDK_HOME}"
OUT="${OUT:-$HERE/build}"
APP="$HERE/android/app/src/main"
JNI="$APP/jniLibs/arm64-v8a"
STRIP="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"

rm -rf "$JNI" "$APP/assets" "$APP/java/org/libsdl"
mkdir -p "$JNI" "$APP/assets" "$APP/java/org/libsdl"

for lib in libSDL2.so libSDL2_image.so libSDL2_ttf.so; do
  cp -L "$PREFIX/lib/$lib" "$JNI/"
done
cp "$OUT/android/libmain.so" "$JNI/libmain.so"
# O servidor local vai como "biblioteca" (única forma de o Android permitir executá-lo)
cp "$OUT/android/freeciv-server" "$JNI/libfreeciv-server.so"
"$STRIP" --strip-unneeded "$JNI"/*.so

cp -r "$PREFIX/sdl-java/app" "$APP/java/org/libsdl/app"

DATA="$(find "$OUT/stage" -type d -path '*/share/freeciv' | head -1)"
[ -n "$DATA" ] || { echo "Dados do jogo não encontrados em $OUT/stage" >&2; exit 1; }
cp -r "$DATA" "$APP/assets/freeciv-data"

cd "$HERE/android"
[ -x ./gradlew ] || gradle wrapper --gradle-version 8.9
./gradlew --no-daemon assembleDebug
cp app/build/outputs/apk/debug/app-debug.apk "$HERE/freeciv-debug.apk"
echo "APK: $HERE/freeciv-debug.apk"
