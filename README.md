# FLEX Replica — implementação independente

Projeto próprio de inspeção de runtime, inspirado em ferramentas de developer inspection. Não contém código recuperado de `Prefs.dylib` nem pretende reproduzir sua implementação.

## Recursos

- Navegação e busca de classes Objective-C, métodos, selectors, propriedades e type encodings.
- Aba **Views** com árvore hierárquica expansível, frames, alpha/hidden e seleção de uma view.
- Aba **Object** com snapshot de propriedades e ivars da view selecionada.
- Opacidade ajustável e persistente; botão para fechar o painel.
- Painel SwiftUI e entrypoint C `FLEXReplicaShowMenu()` incluídos no produto dinâmico `FLEXReplicaCore`.
- A busca inicial de classes agora lista nomes pela ponte Objective-C e adia a introspecção de métodos/propriedades até a seleção.
- Quando a dylib é carregada, um inicializador tenta apresentar o painel uma vez, depois que o app hospedeiro estiver ativo e tiver uma janela em primeiro plano.

## Escopo e limites

A biblioteca não se carrega dentro de um app por conta própria. O app hospedeiro ou um loader existente ainda precisa carregá-la; esta mudança não altera nem reempacota nenhuma IPA. A apresentação automática ocorre somente depois de a dylib entrar no processo. A API `FLEXReplicaShowMenu()` continua disponível para abrir o painel manualmente após a UI estar ativa. Não há hooks Substrate nem edição arbitrária de memória.

## Diagnóstico do crash e correção

O IPS de 19/11/2026 registra `EXC_BREAKPOINT`/`SIGTRAP` no thread principal, com frames em `RuntimeBrowser.classes(matching:)`, `InspectorSession.searchClasses(_:)` e o primeiro layout do painel. A correção evita converter a lista completa de metaclasses do runtime em `AnyClass` no caminho de busca inicial: uma ponte Objective-C retorna somente os nomes e a tela carrega detalhes sob demanda. Isso corresponde ao caminho apontado pelo stack, mas ainda precisa ser confirmado no aparelho/app hospedeiro do usuário.

## Build em macOS/Xcode

```bash
bash Scripts/build_dylib.sh
```

O script produz `dist/ios-device-arm64/libFLEXReplicaCore.dylib` e `dist/ios-simulator-arm64/libFLEXReplicaCore.dylib`, cada variante acompanhada pelo header `FLEXReplicaCore.h`. Para uma IPA de iPhone, somente a variante de dispositivo é aplicável. O app-demo está disponível separadamente via `bash Scripts/build_ios.sh`.

O build CI do crash fix passou em [GitHub Actions #44648702004](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44648702004). O runner compilou as duas dylibs e confirmou os símbolos do painel, autostart e ponte runtime. Os Mach-O baixados são arm64 e registram plataforma iOS e iOS Simulator, respectivamente; o ZIP passou em `unzip -t`. O log contém um aviso não fatal do clang sobre sysroot MacOSX versus target iPhone, embora os load commands finais indiquem as plataformas iOS corretas. XCTest e execução em iPhone/app hospedeiro real não foram realizados.
