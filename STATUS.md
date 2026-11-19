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
