# Status da entrega

## Implementado no código-fonte

O produto dinâmico `FLEXReplicaCore` contém o browser de runtime, o painel SwiftUI, o entrypoint C `FLEXReplicaShowMenu()` e três abas: **Views**, **Classes** e **Object**. A aba Views mostra a hierarquia de `UIView`; selecionar uma linha preenche o inspetor de objeto. O painel também inclui busca de classes, detalhes de métodos/propriedades, opacidade persistente e botão Close.

Um constructor Objective-C no target da dylib tenta apresentar o painel uma única vez quando a biblioteca é carregada. Ele espera o app hospedeiro ficar ativo e ter uma janela em primeiro plano. A função manual continua disponível.

## Build e validação

A compilação CI do autostart desta revisão passou em [GitHub Actions #44645331833](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44645331833). O workflow compilou e empacotou as variantes arm64 de iPhone e simulador; confirmou `FLEXReplicaShowMenu` e o símbolo de retenção do initializer em ambas. Os load commands do Mach-O indicam plataforma iOS na variante device e iOS Simulator na variante de simulador, e a seção de initializer está presente. O ZIP baixado passou na verificação de integridade.

## Integração e testes pendentes

- O app hospedeiro ou um loader existente ainda precisa carregar/vincular a dylib; esta mudança não altera nem reempacota a IPA.
- XCTest e execução visual em app hospedeiro/dispositivo real ainda não foram realizados; o autostart foi compilado e sua seção de initializer conferida, mas não executado num iPhone real.
- A variante de simulador não deve ser incluída em IPA para iPhone.

A biblioteca não implementa um mecanismo para se injetar ou carregar por conta própria.
