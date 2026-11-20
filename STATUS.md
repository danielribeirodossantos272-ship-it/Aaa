# Status da entrega

## Implementado

O produto dinâmico `FLEXReplicaCore` contém o browser de runtime, o painel SwiftUI, o entrypoint C `FLEXReplicaShowMenu()` e as abas **Views**, **Classes** e **Object**. O painel inclui hierarquia de `UIView`, seleção de objetos, métodos/propriedades, opacidade persistente e botão Close. O inicializador tenta apresentar o painel uma vez depois que o app hospedeiro fica ativo.

## Diagnóstico do crash report

O arquivo IPS registra `EXC_BREAKPOINT`/`SIGTRAP` na thread principal. O backtrace passa por `RuntimeBrowser.classes(matching:)`, `InspectorSession.searchClasses(_:)` e o primeiro layout SwiftUI do painel. O crash fix adiciona uma ponte Objective-C para obter nomes das classes e adia a leitura detalhada de métodos/propriedades até o usuário selecionar uma classe. A alteração foi feita somente no código da dylib; nenhuma IPA foi alterada.

## Build e validação

A execução [GitHub Actions #44648702004](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44648702004) passou e gerou as variantes arm64 de iPhone e simulador. Os logs confirmam os símbolos `FLEXReplicaShowMenu`, `FLEXReplicaAutoOpenEnsureLinked` e `FLEXReplicaCopyRuntimeClassNames`. Os load commands dos artefatos indicam plataforma iOS na variante device e iOS Simulator na variante de simulador; o ZIP foi verificado com `unzip -t`.

O log contém um aviso não fatal do clang sobre sysroot MacOSX ao linkar para iPhone; a plataforma final dos dois Mach-O foi verificada separadamente.

## Limitações pendentes

- A correção corresponde ao caminho mostrado no stack, mas ainda não foi validada executando no iPhone ou na IPA do usuário.
- XCTest não foi executado.
- O app hospedeiro ou loader autorizado ainda precisa carregar/vincular a dylib e assiná-la corretamente; esta entrega não altera a IPA.
- A variante de simulador não deve ser incluída em IPA de iPhone.
