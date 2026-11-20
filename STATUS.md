# Status da entrega

## Implementado no código-fonte

O produto dinâmico `FLEXReplicaCore` contém o browser de runtime, o painel SwiftUI, o entrypoint C `FLEXReplicaShowMenu()` e um painel com três abas: **Views**, **Classes** e **Object**. A aba Views mostra a hierarquia de `UIView`; selecionar uma linha preenche o inspetor de objeto. O painel também inclui busca de classes, detalhes de métodos/propriedades, opacidade persistente e botão Close.

A interface é uma aproximação independente com código próprio; não houve inspeção, decompilação ou cópia de `Prefs.dylib` nem alteração de IPA.

## Build e validação

A compilação CI desta revisão foi aprovada em [GitHub Actions #44643782652](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44643782652). O workflow compilou as variantes arm64 de iPhone (iOS 16.0+) e simulador, empacotou os headers e confirmou com `nm` o símbolo `FLEXReplicaShowMenu` em ambas. O ZIP baixado passou na verificação de integridade.

## Integração e testes pendentes

- Um app hospedeiro autorizado precisa carregar/vincular e assinar a dylib, depois chamar `FLEXReplicaMenuLauncher.showMenu()` (Swift) ou `FLEXReplicaShowMenu()` (C/Objective-C) após a UI estar ativa.
- XCTest e execução visual em app hospedeiro/dispositivo real ainda não foram realizados.
- A variante de simulador não deve ser incluída em IPA para iPhone.

A biblioteca não se carrega ou se abre automaticamente e não implementa injeção ou hooks.
