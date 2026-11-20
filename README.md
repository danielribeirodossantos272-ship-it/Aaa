# FLEX Replica — implementação independente

Projeto próprio de inspeção de runtime, inspirado em ferramentas de developer inspection. Não contém código recuperado de `Prefs.dylib` nem pretende reproduzir sua implementação.

## Recursos

- Navegação e busca de classes Objective-C, métodos, selectors, propriedades e type encodings.
- Aba **Views** com árvore hierárquica expansível, frames, alpha/hidden e seleção de uma view.
- Aba **Object** com snapshot de propriedades e ivars da view selecionada.
- Opacidade ajustável e persistente; botão para fechar o painel.
- Painel SwiftUI e entrypoint C `FLEXReplicaShowMenu()` incluídos no produto dinâmico `FLEXReplicaCore`.
- Quando a dylib é carregada, um inicializador tenta apresentar o painel uma vez, depois que o app hospedeiro estiver ativo e tiver uma janela em primeiro plano.

## Escopo e limites

A biblioteca não se carrega dentro de um app por conta própria. O app hospedeiro ou um loader existente ainda precisa carregá-la; esta mudança não altera nem reempacota nenhuma IPA. A apresentação automática ocorre somente depois de a dylib entrar no processo. A API `FLEXReplicaShowMenu()` continua disponível para abrir o painel manualmente após a UI estar ativa. Não há hooks Substrate nem edição arbitrária de memória.

## Build em macOS/Xcode

```bash
bash Scripts/build_dylib.sh
```

O script produz `dist/ios-device-arm64/libFLEXReplicaCore.dylib` e `dist/ios-simulator-arm64/libFLEXReplicaCore.dylib`, cada variante acompanhada pelo header `FLEXReplicaCore.h`. Para uma IPA de iPhone, somente a variante de dispositivo é aplicável. O app-demo está disponível separadamente via `bash Scripts/build_ios.sh`.

A validação CI da nova inicialização automática está pendente. XCTest e execução visual em um app hospedeiro real não são afirmados como aprovados.
