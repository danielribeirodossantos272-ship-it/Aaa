# Status da entrega

## Implementado

- Projeto Swift Package modular e projeto Xcode para iOS.
- `RuntimeBrowser` com classes, superclasses, métodos, selectors, type encodings e propriedades Objective-C.
- `ObjectInspector` com ivars e descrições seguras.
- `ViewHierarchyInspector` para árvore e seleção de UIViews.
- `InspectorSession` isolada no MainActor.
- `PreferencesStore` persistente.
- Painel SwiftUI demonstrativo.
- Testes unitários portáveis.
- Workflow GitHub Actions para build iOS de simulador e upload do artefato.

## Build concluído

- O target `FLEXReplicaDemo` compilou com sucesso para iOS Simulator no GitHub Actions, usando macOS runner, Xcode 26.6 e SDK iPhoneSimulator 26.5.
- Execução: [GitHub Actions #44636780313](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44636780313).
- Artefato `FLEXReplicaDemo-simulator-app` empacotado como `FLEXReplicaDemo-simulator.zip`; a execução guarda o artefato por 30 dias.
- O ZIP foi baixado e a integridade foi verificada nesta entrega.

## Ainda não verificado

- Os testes XCTest não foram executados: o projeto não contém scheme Xcode compartilhado para a ação `test`. O script atual compila o app, mas não executa esses testes.
- Inicialização e inspeção visual do app no simulador.
- Execução em dispositivo físico, assinatura de desenvolvimento e geração de IPA.
- Descoberta de classes e views em runtime dentro de um app real.

## Limitação do artefato

O arquivo produzido é um app de simulador iOS, não um `.ipa` assinado para instalação em iPhone. A instalação em dispositivo exige uma identidade de assinatura Apple do desenvolvedor.

## Auditoria funcional estática — 2026-11-19

Foram corrigidos problemas encontrados no escopo funcional. O navegador busca classes por nome, diferencia métodos de instância e de classe e percorre propriedades herdadas sem duplicá-las. O inspetor separa ivars de propriedades e evita interpretar ivars escalares como objetos. A seleção de views usa coordenadas locais de forma consistente, com sobrecarga explícita para coordenadas de janela. A sessão publica resultados de busca e seleção; o painel SwiftUI lista classes, propriedades e métodos e persiste a opacidade.
