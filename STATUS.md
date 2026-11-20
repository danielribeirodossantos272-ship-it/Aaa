# Status da entrega

## Implementado no código-fonte — aguardando CI

- Aba **Patches** com criação de overrides inativos para propriedades Objective-C graváveis de tipos suportados (strings, números e booleanos).
- Cada patch fica ligado a um único objeto selecionado. Ativar aplica o novo valor; desativar tenta restaurar a base capturada ao ativar; remover apaga a entrada. Se o app mudar a propriedade no meio do caminho, a alteração externa é preservada para evitar sobrescrita.
- As entradas ficam apenas em memória durante o processo e guardam o objeto por referência fraca; não são persistentes e não fazem reidentificação automática após reinício.
- O inicializador da dylib agora instala um botão **FLEX** flutuante e arrastável depois que o app hospedeiro fica ativo; tocar no botão abre o painel. A abertura automática do painel foi removida.
- A ponte Objective-C executa leituras/escritas KVC com captura de exceções. O projeto não implementa patching de código, métodos, executável, loader genérico ou bypass e nenhuma IPA foi alterada.

## Pesquisa de referência

As fontes públicas oficiais do FLEX descrevem inspeção/edição de views e valores de objetos, rede, logs, heap, sandbox, bancos SQLite/Realm e `NSUserDefaults`. Não documentam uma função genérica de criação/ativação de patches como recurso do FLEX. Fontes: [README oficial do FLEX](https://github.com/FLEXTool/FLEX), [artigo da Flipboard](https://about.flipboard.com/engineering/flex/) e [Objective-C Runtime da Apple](https://developer.apple.com/documentation/objectivec/objective-c-runtime). A implementação atual é uma ferramenta independente e limitada a patches de propriedades.

## Build e validação

O código ainda não passou pela nova execução do runner macOS; aguardando build de ambas as variantes arm64 e checagem dos símbolos do botão, painel e ponte KVC. O CI anterior [#44648702004](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44648702004) validou somente a versão anterior da dylib.

## Limitações

- A biblioteca não se carrega por conta própria. O app de teste precisa carregá-la; esta entrega não altera nem reempacota IPA.
- XCTest não foi executado e ainda não houve validação visual em aparelho ou app hospedeiro real.
- Os patches são temporários, aplicados a propriedades Objective-C explicitamente suportadas e a um objeto selecionado; não representam todas as funções do FLEX 3 nem um patcher genérico.
