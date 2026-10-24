#!/usr/bin/env python3
"""Ajustes do Freeciv 3.2.6 para Android.

Uso: patch-freeciv.py <pasta do freeciv-3.2.6>

1. meson.build: o cliente SDL2 vira a biblioteca libmain.so (o SDL2 no Android
   carrega libmain.so e chama SDL_main() dentro dela).
2. client/connectdlg_common.c: o cliente passa a conseguir iniciar o servidor
   LOCAL empacotado no APK (jogo offline, contra a IA, sem internet).
Pode rodar mais de uma vez; guarda backup *.orig.
"""
import pathlib
import shutil
import sys


def write_with_backup(path, text):
    backup = path.with_name(path.name + ".orig")
    if not backup.exists():
        shutil.copy(path, backup)
    path.write_text(text)


def patch_meson(root):
    path = root / "meson.build"
    text = path.read_text()
    if "shared_library('main'," in text:
        return "meson.build: já ajustado"
    start = text.index("executable('freeciv-sdl2',")
    end = text.index("install_data(", start)
    block = text[start:end]
    old_tail = "  install: true,\n  win_subsystem: 'windows'\n"
    if old_tail not in block:
        sys.exit("meson.build: final do alvo freeciv-sdl2 não encontrado")
    block = block.replace("executable('freeciv-sdl2',", "shared_library('main',", 1)
    block = block.replace(old_tail, "  install: true\n", 1)
    write_with_backup(path, text[:start] + block + text[end:])
    return "meson.build: ajustado"


SERVER_HOOK = """#ifdef __ANDROID__
      /* Android: o servidor vai empacotado como libfreeciv-server.so e o
       * app informa o caminho dele em FREECIV_SERVER_BIN. */
      {
        const char *android_srv = getenv("FREECIV_SERVER_BIN");

        if (android_srv != NULL) {
          execv(android_srv, argv);
        }
      }
#endif /* __ANDROID__ */

"""


def patch_server_launch(root):
    path = root / "client" / "connectdlg_common.c"
    text = path.read_text()
    if "FREECIV_SERVER_BIN" in text:
        return "connectdlg_common.c: já ajustado"
    marker = "      /* This line is only reached if freeciv-server cannot be started,"
    if text.count(marker) != 1:
        sys.exit("connectdlg_common.c: ponto de inserção não encontrado")
    write_with_backup(path, text.replace(marker, SERVER_HOOK + marker, 1))
    return "connectdlg_common.c: ajustado"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    print(patch_meson(root))
    print(patch_server_launch(root))
