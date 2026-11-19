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
- O core foi compilado como `libFLEXReplicaCore.dylib` para iPhone arm64 e para simulador arm64 no GitHub Actions [#44638141575](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44638141575).
- A inspeção real de views precisa ser executada em um app-demo em iOS.
- O painel SwiftUI está no app-demo, separado da dylib Core; não há carregador nem injeção automática.

## Build reproduzível em macOS/Xcode

Para compilar as dylibs em um Mac com Xcode:

```bash
bash Scripts/build_dylib.sh
```

O script produz `dist/ios-device-arm64/libFLEXReplicaCore.dylib` e `dist/ios-simulator-arm64/libFLEXReplicaCore.dylib`. O app-demo continua disponível separadamente via `bash Scripts/build_ios.sh`. A dylib contém o core de inspeção; não é um tweak de injeção e precisa ser incorporada e assinada por um app autorizado antes de uso em dispositivo.

## Limitações de segurança e escopo

A implementação foi desenhada para uso dentro de um aplicativo sob controle do desenvolvedor. Ela não implementa integração com a IPA de terceiros analisada anteriormente e não afirma preservar recursos internos do FLEX 3 original.
