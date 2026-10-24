# Freeciv 3.2.6 para Android (offline)

Projeto para gerar o APK do Freeciv de graça no GitHub Actions. **Nada aqui foi compilado ainda**: foi escrito sem NDK, Meson nem internet. Só foram testados os ajustes de código (como edição de texto) e a sintaxe dos scripts, do manifesto e do workflow. Espere corrigir erros no primeiro build.

## Como gerar o APK (grátis, sem instalar nada no PC)
1. Crie uma conta no GitHub e um repositório (público: minutos de build gratuitos; privado: há uma cota gratuita mensal, confira no GitHub).
2. Suba o conteúdo desta pasta (inclusive a pasta oculta `.github`) na raiz do repositório. **Não precisa subir o Freeciv**: o build baixa o código-fonte oficial 3.2.6 sozinho. (O upload pelo navegador do GitHub aceita só 25 MB por arquivo, e o tarball tem 58 MB; se preferir usar o seu, coloque-o na raiz com `git push`.)
3. Aba **Actions**, workflow **Build Freeciv APK**, botão **Run workflow**.
4. Ao terminar, baixe `freeciv-debug-apk` na página da execução e instale o `freeciv-debug.apk` no celular (precisa permitir instalação de fontes desconhecidas).
5. Se falhar, baixe `logs-de-erro` (ou copie o final do log do passo que ficou vermelho) e mande para mim.

O primeiro build é demorado (compila ICU, SDL2, curl e sqlite); as dependências ficam em cache nas próximas execuções.

## O que cada parte faz
- `scripts/patch-freeciv.py`: transforma o cliente SDL2 em `libmain.so` (exigência do SDL2 no Android) e faz o cliente conseguir iniciar o servidor local.
- `scripts/build-native-deps.sh`: compila sqlite, curl (sem TLS), ICU, SDL2, SDL2_image e SDL2_ttf para arm64.
- `scripts/build-freeciv.sh`: compila cliente e servidor com Meson e o NDK.
- `scripts/make-apk.sh`: junta bibliotecas, servidor e dados do jogo no projeto `android/` e roda o Gradle.
- `android/`: app com `FreecivActivity`, que copia os dados do jogo na primeira execução e configura o ambiente.

## Jogo offline
- O servidor do Freeciv vai dentro do APK (`libfreeciv-server.so`) e o cliente o inicia sozinho ao começar uma partida nova contra a IA. Não precisa de internet nem de servidor externo.
- O manifesto ainda pede a permissão `INTERNET`: o Android a exige até para conexão local (127.0.0.1). O app não acessa a internet. Evite abrir a lista de servidores online do cliente.
- Saves ficam na pasta interna do app.

## Toque
O cliente SDL2 do Freeciv já tem tratamento de toque (toque curto, toque longo, arrastar). Não foi alterado: só dá para avaliar e ajustar depois de rodar no celular.

## Riscos conhecidos
- ICU e curl em cross-compile são os pontos mais prováveis de falha.
- O servidor é executado a partir da pasta de bibliotecas do app (único lugar permitido pelo Android 10+); isso depende do `FREECIV_SERVER_BIN` e de `useLegacyPackaging`.
- Interface pensada para mouse: pode ficar com botões pequenos no celular.
- Licença GPL v2: ao distribuir o APK, o código-fonte do Freeciv precisa acompanhar.
