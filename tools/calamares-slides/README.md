# Mainuan — apresentação do instalador Calamares

Este diretório contém a fonte QML do slideshow final, os catálogos Qt Linguist, os utilitários de validação e os procedimentos usados para aplicar a correção da tela inicial em português brasileiro.

## Arquivos

- `show.qml`: cinco slides, texto traduzido por `qsTr()`, layout ajustável e validado em diferentes proporções e idiomas.
- `lang/`: 34 catálogos Qt Linguist. O inglês é a fonte e o fallback do QML; não necessita de catálogo separado.
- `build-translations.sh`: compila os catálogos com Qt 6 e instala os arquivos `.qm`.
- `validate-translations.py`: verifica o conjunto de idiomas, as chaves de origem e a presença das traduções.
- `patch-installer-welcome-pt_BR.sh`: altera o texto da tela inicial e o nome da etapa lateral do Calamares para “Boas-vindas”, preservando as demais traduções.
- `sync-approved-assets.sh`: sincroniza o QML, as cinco imagens aprovadas e os 34 catálogos-fonte do projeto Mainuan para este repositório.

## Validar os catálogos

Depois de sincronizar os 34 arquivos-fonte com `sync-approved-assets.sh`, execute na raiz do repositório:

```bash
python3 tools/calamares-slides/validate-translations.py
```

## Compilar as traduções

```bash
bash tools/calamares-slides/build-translations.sh
```

O destino padrão é `build/base/chroot/etc/calamares/branding/vendor/lang`. Um destino alternativo pode ser passado como primeiro argumento.

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

A rotina copia `show.qml` e `images/slide-1.png` até `images/slide-5.png` do chroot testado para `rootfs/etc/calamares/branding/vendor/`. Também copia os 34 arquivos `.ts` do diretório `Mainuan/tools/calamares-slides/lang/` para este repositório. Antes de substituir qualquer recurso, cria um backup local em `~/Downloads` por padrão e, ao final, executa o validador de traduções.

Depois da sincronização, revise o diff e confira os cinco PNGs antes de criar o commit. O catálogo interno `calamares_pt_BR.qm` faz parte do pacote binário do Calamares; a correção dele é aplicada ao chroot pelo script específico acima.

## Idiomas

`ar`, `bn`, `cs`, `da`, `de`, `el`, `es`, `fa`, `fi`, `fr`, `he`, `hi`, `hu`, `id`, `it`, `ja`, `ko`, `nb`, `nl`, `pl`, `pt`, `pt_BR`, `pt_PT`, `ro`, `ru`, `sv`, `sw`, `th`, `tr`, `uk`, `ur`, `vi`, `zh_CN` e `zh_TW`.
