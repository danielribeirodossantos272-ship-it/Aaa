# Status da entrega

## Implementado no código-fonte

O produto dinâmico `FLEXReplicaCore` contém o browser de runtime, o painel SwiftUI, o entrypoint C `FLEXReplicaShowMenu()` e três abas: **Views**, **Classes** e **Object**. A aba Views mostra a hierarquia de `UIView`; selecionar uma linha preenche o inspetor de objeto. O painel também inclui busca de classes, detalhes de métodos/propriedades, opacidade persistente e botão Close.

Um constructor Objective-C no target da dylib tenta apresentar o painel uma única vez quando a biblioteca é carregada. Ele espera o app hospedeiro ficar ativo e ter uma janela em primeiro plano. A função manual continua disponível.

## Build e validação

A compilação CI do autostart desta revisão está pendente. O build anterior aprovou o painel expandido, mas não contém o constructor automático; não o tratar como validação desta alteração.

## Integração e testes pendentes

- O app hospedeiro ou um loader existente ainda precisa carregar/vincular a dylib; esta mudança não altera nem reempacota a IPA.
- XCTest e execução visual em app hospedeiro/dispositivo real ainda não foram realizados.
- A variante de simulador não deve ser incluída em IPA para iPhone.

A biblioteca não implementa um mecanismo para se injetar ou carregar por conta própria.
