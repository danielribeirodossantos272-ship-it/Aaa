# FLEX 3 Replica — Independent Implementation

Projeto independente inspirado em ferramentas de inspeção de runtime. Não contém código recuperado da `Prefs.dylib` e não pretende reproduzir o código original.

## Implementado no código-fonte

- Navegação de classes Objective-C via runtime (`objc_copyClassList`).
- Inspeção de métodos, selectors e type encodings.
- Inspeção de ivars e descrições de valores de objetos.
- Construção recursiva da hierarquia de `UIView`.
- Seleção de view por ponto convertido para o sistema de coordenadas da raiz.
- Sessão de inspeção `@MainActor`.
- Preferências persistentes com `UserDefaults` e Codable.
- Painel SwiftUI independente com busca de classes e listagem de selectors.
- Testes unitários para preferências e criação do navegador.

## Não implementado ou não verificado

- Não há mecanismo de injeção em processos de terceiros.
- Não há hooks Substrate, stubs de `MSHookMessageEx` ou alteração de IPA.
- Não há edição arbitrária de memória.
- Este sandbox Linux não possui Xcode; o target `FLEXReplicaDemo` foi compilado para iOS Simulator no GitHub Actions [#44636780313](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44636780313).
- A inspeção real de views precisa ser executada em um app-demo em iOS.
- O painel está hospedado no app-demo; a interação visual ainda não foi verificada executando o app.

## Build reproduzível em macOS/Xcode

Abra `FLEXReplica.xcodeproj` no Xcode. O projeto contém os targets `FLEXReplicaDemo` e `FLEXReplicaTests`; selecione um Team de desenvolvimento em Signing & Capabilities antes de instalar em um iPhone. Nenhuma identidade de assinatura foi embutida no projeto.

```bash
chmod +x Scripts/build_ios.sh
./Scripts/build_ios.sh
```

O script falha explicitamente se `xcodebuild` não estiver disponível e compila o app para iOS Simulator. Os testes XCTest ainda não são executados pelo script porque o projeto não inclui um scheme Xcode compartilhado. O artefato de simulador não é um `.ipa`; para instalar em iPhone, configure uma identidade de desenvolvimento e compile/assine para dispositivo no Xcode.

## Limitações de segurança e escopo

A implementação foi desenhada para uso dentro de um aplicativo sob controle do desenvolvedor. Ela não implementa integração com a IPA de terceiros analisada anteriormente e não afirma preservar recursos internos do FLEX 3 original.
