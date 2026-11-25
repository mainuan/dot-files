# Mainuan — apresentação do instalador Calamares

Este diretório contém a fonte QML do slideshow final, os catálogos Qt Linguist, os utilitários de validação e os procedimentos usados para aplicar a correção da tela inicial em português brasileiro.

## Arquivos

- `show.qml`: cinco slides, texto traduzido por `qsTr()`, layout ajustável e validado em diferentes proporções e idiomas.
- `lang/`: 34 catálogos Qt Linguist. O inglês é a fonte e o fallback do QML; não necessita de catálogo separado.
- `build-translations.sh`: compila os catálogos com Qt 6 e instala os arquivos `.qm`.
- `validate-translations.py`: verifica o conjunto de idiomas, as chaves de origem e a presença das traduções.
- `patch-installer-welcome-pt_BR.sh`: altera o texto da tela inicial e o nome da etapa lateral do Calamares para “Boas-vindas”, preservando as demais traduções.
- `sync-approved-assets.sh`: sincroniza o QML, as cinco imagens, os catálogos compilados e o catálogo pt_BR do Calamares a partir do chroot aprovado; recupera os 34 arquivos `.ts` com `lconvert`.

## Validar os catálogos

Depois de sincronizar os 34 arquivos-fonte com `sync-approved-assets.sh`, execute na raiz do repositório:

```bash
python3 tools/calamares-slides/validate-translations.py
```

## Compilar as traduções

```bash
bash tools/calamares-slides/build-translations.sh \
  "/caminho/para/Mainuan/build/base/chroot/etc/calamares/branding/vendor/lang"
```

O destino é obrigatório para evitar compilar acidentalmente em uma árvore de build diferente da que está sendo testada.

## Corrigir a tela inicial do Calamares

```bash
bash tools/calamares-slides/patch-installer-welcome-pt_BR.sh \
  "/caminho/para/Mainuan/build/base/chroot"
```

A rotina altera somente as quatro variantes do título de boas-vindas e as duas variantes do nome da etapa lateral no catálogo `calamares_pt_BR.qm`. O catálogo original é preservado em `~/Downloads` por padrão.

## Sincronizar os recursos finais para este repositório

Depois de aprovar o ISO de teste, execute:

```bash
bash tools/calamares-slides/sync-approved-assets.sh \
  "/caminho/para/dot-files" \
  "/caminho/para/Mainuan"
```

A rotina usa exclusivamente os artefatos do chroot testado: copia o `show.qml` aprovado para `rootfs/` e `tools/`, as cinco imagens para `rootfs/etc/calamares/branding/vendor/images/` e os 34 catálogos compilados para `rootfs/etc/calamares/branding/vendor/lang/`. Em seguida, recupera os arquivos `.ts` correspondentes diretamente dos `.qm` usando `lconvert` do Qt 6 e os guarda em `tools/calamares-slides/lang/`. Também copia o catálogo interno `calamares_pt_BR.qm` já corrigido para `rootfs/usr/share/calamares/lang/`. Antes de substituir qualquer recurso, cria um backup local em `~/Downloads` por padrão e valida os catálogos comparando as chaves com as chamadas `qsTr()` do próprio QML aprovado.

Depois da sincronização, revise o diff e confira os cinco PNGs antes de criar o commit.

## Idiomas

`ar`, `bn`, `cs`, `da`, `de`, `el`, `es`, `fa`, `fi`, `fr`, `he`, `hi`, `hu`, `id`, `it`, `ja`, `ko`, `nb`, `nl`, `pl`, `pt`, `pt_BR`, `pt_PT`, `ro`, `ru`, `sv`, `sw`, `th`, `tr`, `uk`, `ur`, `vi`, `zh_CN` e `zh_TW`.
