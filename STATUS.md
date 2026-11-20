# Status de entrega

## Implementado

- Projeto Swift Package modular.
- `RuntimeBrowser` com classes, superclasses, métodos, selectors e type encodings.
- `ObjectInspector` com ivars e descrições seguras.
- `ViewHierarchyInspector` para árvore e seleção de UIViews.
- `InspectorSession` isolada no MainActor.
- `PreferencesStore` persistente.
- Painel SwiftUI demonstrativo.
- Testes unitários portáveis.
- Script de build que exige macOS/Xcode.

## Testado neste ambiente

- Integridade e existência dos arquivos-fonte.
- Consistência textual do manifesto e scripts.
- Não foi possível executar `swift test` para um target iOS/UIKit porque o ambiente atual não possui SDK iOS.

## Não testado

- Compilação com Xcode.
- Execução em simulador iOS.
- Execução em dispositivo iOS 26.3.1.
- Descoberta de classes e views em runtime Apple.
- Interação visual do painel.

## Compiled test build

Não entregue. Não há Xcode nem SDK iOS neste ambiente, portanto não existe um `.app` compilado honestamente para anexar. O script de build documenta a etapa necessária em macOS.


## Auditoria e configuração Xcode — 2026-11-19

Foi adicionado `FLEXReplica.xcodeproj` com um target de aplicativo iOS `FLEXReplicaDemo` e um target de testes `FLEXReplicaTests`. O target usa deployment target iOS 16.0, inclui o `DemoApp/Info.plist`, compila os módulos Core e Demo e configura o host de testes.

A assinatura está em modo `Automatic`, sem `DEVELOPMENT_TEAM` definido. Isso é intencional: uma identidade de desenvolvimento pertence ao ambiente Apple do desenvolvedor e não foi inventada. Ao abrir no Xcode, selecione o time de desenvolvimento e o bundle identifier apropriado.

A auditoria local verificou IDs de objetos sem duplicidade, referências aos fontes existentes, presença do Info.plist, ausência de placeholders e integridade do ZIP. A compilação Xcode continua não executada porque este ambiente não contém macOS, Xcode, Swift ou SDK iOS.


## Auditoria funcional estática — 2026-11-19

Foram corrigidos problemas encontrados no escopo funcional. O navegador agora expõe metadados de propriedades Objective-C, busca classes diretamente por nome, diferencia métodos de instância e de classe e percorre propriedades herdadas sem duplicá-las. O inspetor de objetos agora separa ivars de propriedades e evita interpretar ivars escalares como objetos. A seleção de views foi corrigida para usar coordenadas locais de forma consistente, com uma sobrecarga explícita para pontos em coordenadas de janela. A sessão publica resultados de busca e seleção. O painel SwiftUI passou a mostrar classes encontradas, propriedades, métodos e persistir a opacidade.

Os testes unitários foram ampliados para round-trip de preferências, valores padrão, métodos de `NSObject` e metadados de propriedades em targets UIKit. Essas mudanças foram revisadas estaticamente, mas não foram compiladas neste ambiente.


## Patches de método + correções de build — 2026-11-19

Adicionados `PatchEngine.swift` (modelo `MethodPatch`, `PatchManager`, fábrica de IMP por tipo de retorno), `PatchesView.swift` (criar patch e lista com switches) e botões no `FLEXReplicaPanel`. Cinco testes novos cobrem toggle de BOOL, int/objeto/método de classe, persistência, erros e parsing de tipos. O `project.pbxproj` foi atualizado (IDs verificados: sem duplicatas e sem referências soltas).

Correções de build encontradas na revisão estática:
- `main.swift` renomeado para `FLEXReplicaDemoApp.swift`: `@main` não é permitido em arquivo chamado `main.swift`.
- `import FLEXReplicaCore` agora é condicional (`#if canImport(FLEXReplicaCore)`): no `.xcodeproj` os fontes do Core são compilados direto nos targets, então o módulo separado não existe (ele só existe via Swift Package).

Continua **não compilado e não executado**: este ambiente não tem Swift, Xcode nem SDK iOS.


## Dylib — 2026-11-19

Adicionados `Dylib/entry.c`, `Dylib/Bootstrap.swift` e `Scripts/build_dylib.sh`. **Não compilado nem testado** (sem macOS/Xcode neste ambiente). Fora do `.xcodeproj` de propósito: o script compila tudo como um único módulo `FLEXReplica`, por isso os `import FLEXReplicaCore` condicionais não são ativados nesse build.

Funções do FLEX ainda **sem interface** (existem só no Core): inspeção de objetos/ivars e árvore de views. Não existem: seleção de view por toque, heap, rede, arquivos, UserDefaults.


## Seleção de view por toque — 2026-11-19

Adicionado `Dylib/ViewPicker.swift` (localizador da view sob o toque, modelo de seleção e tela de detalhes) e o modo de captura/realce em `Dylib/Bootstrap.swift`. O painel aceita `initialClass` para abrir direto numa classe. **Não compilado nem testado.** Pontos a validar em dispositivo: toque em views dentro de `UIScrollView`/células, janelas de teclado, e telas com `clipsToBounds` (o localizador usa `ViewHierarchyInspector.view(at:in:)`, que não considera `clipsToBounds`).


## GitHub Actions — 2026-11-19

Adicionado `.github/workflows/build-dylib.yml` para compilar a fonte enviada em runner macOS. Esta cópia de build será executada na branch isolada `build/flex-replica-github-20261119`, sem substituir a branch `main` do repositório Aaa.
