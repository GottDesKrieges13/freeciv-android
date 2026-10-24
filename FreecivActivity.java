package org.freeciv.android;

import android.os.Bundle;
import android.system.Os;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import org.libsdl.app.SDLActivity;

/** Atividade do Freeciv: prepara dados e variáveis de ambiente e inicia o cliente SDL2. */
public class FreecivActivity extends SDLActivity {

    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "SDL2_image", "SDL2_ttf", "main" };
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        try {
            prepareEnvironment();
        } catch (Exception e) {
            throw new RuntimeException("Falha ao preparar os dados do Freeciv", e);
        }
        super.onCreate(savedInstanceState);
    }

    private void prepareEnvironment() throws Exception {
        File files = getFilesDir();
        File data = new File(files, "freeciv-data");
        File marker = new File(files, "freeciv-data.stamp");

        // Copia os dados do jogo (tilesets, rulesets) na primeira execução e a cada atualização do app
        String stamp = String.valueOf(
                getPackageManager().getPackageInfo(getPackageName(), 0).lastUpdateTime);
        if (!marker.exists() || !stamp.equals(readText(marker))) {
            deleteRecursively(data);
            copyAssetDir("freeciv-data", data);
            writeText(marker, stamp);
        }

        Os.setenv("HOME", files.getAbsolutePath(), true);            // saves em ~/.freeciv
        Os.setenv("TMPDIR", getCacheDir().getAbsolutePath(), true);
        Os.setenv("FREECIV_DATA_PATH", data.getAbsolutePath(), true);
        Os.setenv("FREECIV_SERVER_BIN",
                getApplicationInfo().nativeLibraryDir + "/libfreeciv-server.so", true);
    }

    private void copyAssetDir(String assetPath, File dest) throws IOException {
        String[] names = getAssets().list(assetPath);
        if (names == null || names.length == 0) {
            copyAssetFile(assetPath, dest);
            return;
        }
        dest.mkdirs();
        for (String name : names) {
            copyAssetDir(assetPath + "/" + name, new File(dest, name));
        }
    }

    private void copyAssetFile(String assetPath, File dest) throws IOException {
        try (InputStream in = getAssets().open(assetPath);
             OutputStream out = new FileOutputStream(dest)) {
            byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
            }
        }
    }

    private static void deleteRecursively(File f) {
        File[] children = f.listFiles();
        if (children != null) {
            for (File c : children) {
                deleteRecursively(c);
            }
        }
        f.delete();
    }

    private static String readText(File f) throws IOException {
        byte[] buf = new byte[(int) f.length()];
        try (InputStream in = new java.io.FileInputStream(f)) {
            int off = 0;
            while (off < buf.length) {
                int n = in.read(buf, off, buf.length - off);
                if (n < 0) {
                    break;
                }
                off += n;
            }
        }
        return new String(buf);
    }

    private static void writeText(File f, String s) throws IOException {
        try (OutputStream out = new FileOutputStream(f)) {
            out.write(s.getBytes());
        }
    }
}
