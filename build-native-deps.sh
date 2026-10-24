#!/bin/bash
# Compila as dependências do Freeciv para Android arm64 e instala em $PREFIX.
# NÃO TESTADO: escrito sem NDK/internet. Se algo falhar, o log mostra onde.
set -euo pipefail

NDK="${ANDROID_NDK_HOME:?defina ANDROID_NDK_HOME}"
PREFIX="${PREFIX:?defina PREFIX}"
API="${API:-24}"
ABI=arm64-v8a
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TC/bin/aarch64-linux-android$API-clang"
export CXX="$TC/bin/aarch64-linux-android$API-clang++"
export AR="$TC/bin/llvm-ar"
export RANLIB="$TC/bin/llvm-ranlib"
JOBS="$(nproc)"
W="${WORK:-$PWD/deps-work}"
mkdir -p "$W" "$PREFIX/lib/pkgconfig" "$PREFIX/include"
cd "$W"

fetch() { [ -f "$2" ] || curl -fL --retry 3 -o "$2" "$1"; }

CMAKE_COMMON=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API"
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX"
  -DCMAKE_FIND_ROOT_PATH="$PREFIX" -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

echo "== sqlite3"
fetch https://www.sqlite.org/2024/sqlite-amalgamation-3460000.zip sqlite.zip
unzip -qo sqlite.zip
"$CC" -O2 -fPIC -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
  -c sqlite-amalgamation-3460000/sqlite3.c -o sqlite3.o
"$AR" rcs "$PREFIX/lib/libsqlite3.a" sqlite3.o
cp sqlite-amalgamation-3460000/sqlite3.h sqlite-amalgamation-3460000/sqlite3ext.h "$PREFIX/include/"

echo "== curl (sem TLS: o jogo é offline, o Freeciv só exige a biblioteca para linkar)"
fetch https://curl.se/download/curl-8.10.1.tar.xz curl.tar.xz
tar -xf curl.tar.xz
cmake -S curl-8.10.1 -B build-curl "${CMAKE_COMMON[@]}" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_CURL_EXE=OFF -DBUILD_TESTING=OFF \
  -DCURL_ENABLE_SSL=OFF -DCURL_USE_OPENSSL=OFF -DCURL_USE_LIBPSL=OFF \
  -DUSE_LIBIDN2=OFF -DUSE_NGHTTP2=OFF -DCURL_USE_LIBSSH2=OFF \
  -DCURL_DISABLE_LDAP=ON -DCURL_DISABLE_LDAPS=ON -DHTTP_ONLY=ON
cmake --build build-curl -j"$JOBS"
cmake --install build-curl

echo "== ICU (build do host primeiro, depois cruzado)"
fetch https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz icu.tgz
tar -xzf icu.tgz
mkdir -p icu-host && (cd icu-host && ../icu/source/runConfigureICU Linux >/dev/null && make -j"$JOBS")
mkdir -p icu-android && cd icu-android
CFLAGS="-fPIC -O2" CXXFLAGS="-fPIC -O2" ../icu/source/configure \
  --host=aarch64-linux-android --with-cross-build="$W/icu-host" --prefix="$PREFIX" \
  --enable-static --disable-shared --disable-tools --disable-tests --disable-samples \
  --disable-extras --disable-icuio --disable-layoutex
make -j"$JOBS"
make install
cd "$W"
# libicuuc.a é C++: o link do Freeciv (clang C) precisa da libc++ estática
sed -i 's/^Libs:.*/& -lc++_static -lc++abi/' "$PREFIX/lib/pkgconfig/icu-uc.pc"

echo "== SDL2"
SDL_V=2.30.9
fetch "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_V/SDL2-$SDL_V.tar.gz" sdl2.tgz
tar -xzf sdl2.tgz
cmake -S "SDL2-$SDL_V" -B build-sdl2 "${CMAKE_COMMON[@]}" \
  -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF -DSDL_TESTS=OFF
cmake --build build-sdl2 -j"$JOBS"
cmake --install build-sdl2
mkdir -p "$PREFIX/sdl-java"
cp -r "SDL2-$SDL_V/android-project/app/src/main/java/org/libsdl/app" "$PREFIX/sdl-java/"

echo "== SDL2_image"
IMG_V=2.8.2
fetch "https://github.com/libsdl-org/SDL_image/releases/download/release-$IMG_V/SDL2_image-$IMG_V.tar.gz" img.tgz
tar -xzf img.tgz
cmake -S "SDL2_image-$IMG_V" -B build-img "${CMAKE_COMMON[@]}" \
  -DBUILD_SHARED_LIBS=ON -DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_BACKEND_STB=ON \
  -DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_JXL=OFF -DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_WEBP=OFF
cmake --build build-img -j"$JOBS"
cmake --install build-img

echo "== SDL2_ttf"
TTF_V=2.22.0
fetch "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$TTF_V/SDL2_ttf-$TTF_V.tar.gz" ttf.tgz
tar -xzf ttf.tgz
cmake -S "SDL2_ttf-$TTF_V" -B build-ttf "${CMAKE_COMMON[@]}" \
  -DBUILD_SHARED_LIBS=ON -DSDL2TTF_VENDORED=ON -DSDL2TTF_HARFBUZZ=OFF -DSDL2TTF_SAMPLES=OFF
cmake --build build-ttf -j"$JOBS"
cmake --install build-ttf

echo "== Dependências prontas em $PREFIX"
ls "$PREFIX/lib" "$PREFIX/lib/pkgconfig"
