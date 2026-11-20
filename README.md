# FLEX Replica — implementação independente

Projeto próprio de inspeção de runtime, inspirado em ferramentas de developer inspection. Não contém código recuperado de `Prefs.dylib` nem pretende reproduzir sua implementação.

## Recursos

- Navegação e busca de classes Objective-C, métodos, selectors, propriedades e type encodings.
- Aba **Views** com árvore hierárquica expansível, frames, alpha/hidden e seleção de uma view.
- Aba **Object** com snapshot de propriedades e ivars da view selecionada.
- Opacidade ajustável e persistente; botão para fechar o painel.
- Painel SwiftUI e entrypoint C `FLEXReplicaShowMenu()` incluídos no produto dinâmico `FLEXReplicaCore`.

## Escopo e limites

A implementação é independente: não tem carregador, injeção em processos, hooks Substrate, edição arbitrária de memória nem alteração de IPA. O app hospedeiro deve carregar/vincular e assinar a dylib; depois que sua UI estiver ativa, deve chamar `FLEXReplicaMenuLauncher.showMenu()` em Swift ou `FLEXReplicaShowMenu()` usando `FLEXReplicaCore.h` em C/Objective-C. A biblioteca não aparece nem abre automaticamente só por existir num pacote.

## Build em macOS/Xcode

```bash
bash Scripts/build_dylib.sh
```

O script produz `dist/ios-device-arm64/libFLEXReplicaCore.dylib` e `dist/ios-simulator-arm64/libFLEXReplicaCore.dylib`, cada variante acompanhada pelo header `FLEXReplicaCore.h`. Para uma IPA de iPhone, somente a variante de dispositivo é aplicável. O app-demo está disponível separadamente via `bash Scripts/build_ios.sh`.

A compilação CI da interface expandida foi aprovada: [GitHub Actions #44643782652](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44643782652). As duas dylibs e headers foram empacotados; `FLEXReplicaShowMenu` foi confirmado como símbolo exportado. XCTest e execução visual em um app hospedeiro real não foram realizados.
