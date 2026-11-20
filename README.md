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

## Patches de método (criar / ativar / desativar)

- `PatchManager` (`PatchEngine.swift`) cria patches do tipo "este método passa a retornar X", liga/desliga cada um, remove e persiste em `UserDefaults`. Chame `PatchManager.shared.applyEnabledPatches()` no início do app para reaplicar os habilitados.
- Tipos de retorno suportados: `void` (vira no-op), `BOOL`, `int`, `long/NSInteger`, `float`, `double`, objeto (`texto`, `nil`, `@YES`, `@42`) e `Class`. Structs e ponteiros não são suportados.
- Só métodos visíveis ao runtime Objective-C (`@objc`/herdados de `NSObject`) e sem parâmetros explícitos. O patch usa `class_replaceMethod`; desativar restaura o IMP original. Métodos com parâmetros são recusados pelo backend para não aplicar um IMP com assinatura incompatível.
- No painel: botão **Patch** ao lado de cada método e botão **Patches (n)** para listar/ativar/desativar/apagar.

## Dylib (`FLEXReplica.dylib`)

`./Scripts/build_dylib.sh` compila Core + painel + patches + `Dylib/Bootstrap.swift` em uma `.dylib` (`SDK=iphonesimulator` para simulador). Ao carregar, o `constructor` em `Dylib/entry.c` reaplica os patches salvos e, quando o app fica ativo, mostra dois botões flutuantes: 🐞 abre o painel (classes, métodos, patches) e o visor (viewfinder) liga o modo de seleção — toque em qualquer view do app para realçá-la e ver classe, frame, view controller, cadeia de superviews, subviews, propriedades e ivars (toque em uma linha para navegar na hierarquia).

Para usar no **seu próprio app**: no Xcode, arraste `FLEXReplica.dylib` para o target e deixe em *Frameworks, Libraries, and Embedded Content* como **Embed & Sign**.

## Build no GitHub Actions

`.github/workflows/build-dylib.yml` compila `FLEXReplica.dylib` (dispositivo e simulador) em um runner macOS a cada push, ou manualmente em **Actions → Build FLEXReplica.dylib → Run workflow**. O resultado fica em **Artifacts** no fim da execução (`FLEXReplica-dylib-iphoneos` / `-iphonesimulator`), junto com o log do build (`build-log-*`). Um job extra tenta compilar o app demo e não bloqueia o resto.

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
