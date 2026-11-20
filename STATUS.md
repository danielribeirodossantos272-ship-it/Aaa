# Status da entrega

## Implementado no código-fonte

O produto dinâmico `FLEXReplicaCore` contém o browser de runtime, o painel SwiftUI, o entrypoint C `FLEXReplicaShowMenu()` e um painel com três abas: **Views**, **Classes** e **Object**. A aba Views mostra a hierarquia de `UIView`; selecionar uma linha preenche o inspetor de objeto. O painel também inclui busca de classes, detalhes de métodos/propriedades, opacidade persistente e botão Close.

A interface é uma aproximação independente com código próprio; não houve inspeção, decompilação ou cópia de `Prefs.dylib` nem alteração de IPA.

## Build e validação

A compilação CI desta revisão está pendente. O workflow deverá compilar as variantes arm64 de iPhone (iOS 16.0+) e simulador e confirmar o símbolo exportado. O build anterior aprovou apenas a versão anterior do painel; não o usar como validação desta UI ampliada.

## Integração e testes pendentes

- Um app hospedeiro autorizado precisa carregar/vincular e assinar a dylib, depois chamar `FLEXReplicaMenuLauncher.showMenu()` (Swift) ou `FLEXReplicaShowMenu()` (C/Objective-C) após a UI estar ativa.
- XCTest e execução visual em app hospedeiro/dispositivo real ainda não foram realizados.
- A variante de simulador não deve ser incluída em IPA para iPhone.

A biblioteca não se carrega ou se abre automaticamente e não implementa injeção ou hooks.
