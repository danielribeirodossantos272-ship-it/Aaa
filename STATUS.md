# Status da entrega

## Implementado

- Projeto Swift Package modular e projeto Xcode para iOS.
- `FLEXReplicaCore` é um produto dinâmico com `RuntimeBrowser`, `ObjectInspector`, `ViewHierarchyInspector`, `InspectorSession` e `PreferencesStore`.
- Painel SwiftUI demonstrativo separado no app-demo.
- Script e workflow macOS para compilar dylibs para iPhone arm64 e simulador arm64.

## Dylibs compiladas

- `libFLEXReplicaCore.dylib` para iPhone arm64, iOS 16.0+.
- `libFLEXReplicaCore.dylib` para simulador iOS arm64.
- Execução CI aprovada: [GitHub Actions #44638141575](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44638141575).
- O pacote `FLEXReplicaCore-dylibs` foi baixado; ambos os binários foram verificados como Mach-O arm64 dinamicamente vinculados e o ZIP passou na verificação de integridade.

## Ainda não verificado

- Testes XCTest e execução em dispositivo/simulador.
- Carregamento da dylib em um app hospedeiro real.
- Assinatura e distribuição de um `.ipa`.

## Escopo do binário

A dylib contém o core de inspeção; o painel SwiftUI permanece no app-demo. Não existe carregador, hook ou mecanismo de injeção automática. Para uso em um app próprio, a biblioteca precisa ser incorporada e assinada pelo app hospedeiro. O artefato não é um `.app` nem um `.ipa`.

## Auditoria funcional estática — 2026-11-19

O navegador busca classes por nome, diferencia métodos de instância e de classe e percorre propriedades herdadas sem duplicá-las. O inspetor separa ivars de propriedades e evita interpretar ivars escalares como objetos. A seleção de views usa coordenadas locais de forma consistente, com sobrecarga explícita para coordenadas de janela. A sessão publica resultados de busca e seleção; o painel SwiftUI lista classes, propriedades e métodos e persiste a opacidade.
