#!/bin/bash
# Compila o Freeciv (cliente SDL2 + servidor local) para Android arm64.
# NÃO TESTADO: escrito sem NDK/Meson/internet.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:?defina PREFIX (saída do build-native-deps.sh)}"
NDK="${ANDROID_NDK_HOME:?defina ANDROID_NDK_HOME}"
API="${API:-24}"
OUT="${OUT:-$HERE/build}"
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
mkdir -p "$OUT"

# 1. Código-fonte: o tarball do Freeciv fica na raiz do projeto
if [ ! -d "$OUT/src" ]; then
  TARBALL="$(find "$HERE" -maxdepth 1 \( -name 'freeciv-*.tar.xz' -o -name 'freeciv-*_tar.xz' \) | head -1)"
  if [ -z "$TARBALL" ]; then
    # Sem tarball no projeto: baixa o código-fonte oficial (SourceForge)
    TARBALL="$OUT/freeciv-3.2.6.tar.xz"
    for url in \
      "https://sourceforge.net/projects/freeciv/files/Freeciv%203.2/3.2.6/freeciv-3.2.6.tar.xz/download" \
      "https://prdownloads.sourceforge.net/freeciv/freeciv-3.2.6.tar.xz"; do
      if curl -fL --retry 3 -o "$TARBALL" "$url" && tar -tf "$TARBALL" > /dev/null 2>&1; then
        break
      fi
      rm -f "$TARBALL"
    done
    [ -s "$TARBALL" ] || { echo "Não consegui baixar o Freeciv 3.2.6. Coloque o tarball na raiz do projeto." >&2; exit 1; }
  fi
  mkdir -p "$OUT/src"
  tar -xf "$TARBALL" -C "$OUT/src" --strip-components=1
fi
SRC="$OUT/src"
python3 "$HERE/scripts/patch-freeciv.py" "$SRC"

# 2. tolua nativo (o build cruzado do Freeciv precisa de um tolua do PC)
if [ ! -x "$OUT/host/tolua" ]; then
  meson setup "$OUT/host" "$SRC" -Dclients=stub -Dserver=disabled "-Dfcmp=[]" "-Dtools=[]" \
    -Daudio=none -Dnls=false -Dmwand=false -Dsyslua=false -Dreadline=false
  ninja -C "$OUT/host" tolua
fi

# 3. Build cruzado
sed -e "s,<TC>,$TC,g" -e "s,<API>,$API,g" -e "s,<PREFIX>,$PREFIX,g" \
    -e "s,<TOLUA>,$OUT/host/tolua,g" \
    "$HERE/scripts/cross-android-arm64.ini.tmpl" > "$OUT/cross.ini"

rm -rf "$OUT/android"
meson setup "$OUT/android" "$SRC" --cross-file "$OUT/cross.ini" \
  --buildtype=release -Db_pie=true -Ddefault_library=static \
  -Dclients=sdl2 -Dserver=enabled "-Dfcmp=[]" "-Dtools=[]" \
  -Daudio=none -Dnls=false -Dmwand=false -Dsyslua=false -Dreadline=false
ninja -C "$OUT/android"

rm -rf "$OUT/stage"
DESTDIR="$OUT/stage" meson install -C "$OUT/android" --no-rebuild
echo "Pronto: $OUT/android/libmain.so e $OUT/android/freeciv-server"
