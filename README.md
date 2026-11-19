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
- O projeto não foi compilado neste ambiente: Linux não possui Xcode, UIKit executável ou simulador iOS.
- A inspeção real de views precisa ser executada em um app-demo em iOS.
- O `FLEXReplicaPanel` é uma interface funcional de demonstração, mas ainda precisa ser hospedado em um projeto Xcode iOS para teste visual.

## Build reproduzível em macOS/Xcode

Abra `FLEXReplica.xcodeproj` no Xcode. O projeto contém os targets `FLEXReplicaDemo` e `FLEXReplicaTests`; selecione um Team de desenvolvimento em Signing & Capabilities antes de instalar em um iPhone. Nenhuma identidade de assinatura foi embutida no projeto.

```bash
chmod +x Scripts/build_ios.sh
./Scripts/build_ios.sh
```

O script falha explicitamente se `xcodebuild` não estiver disponível. Para um build iOS real, crie/abra um workspace Xcode que inclua este Swift Package, configure um target iOS para `FLEXReplicaDemo`, assine com uma identidade de desenvolvimento e execute em simulador ou dispositivo.

## Limitações de segurança e escopo

A implementação foi desenhada para uso dentro de um aplicativo sob controle do desenvolvedor. Ela não implementa integração com a IPA de terceiros analisada anteriormente e não afirma preservar recursos internos do FLEX 3 original.
