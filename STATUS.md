# Status da entrega

## Edição de strings — build anterior concluída

- Aba **Patches** com criação de overrides inativos para propriedades Objective-C graváveis de tipos suportados (strings, números e booleanos).
- A inspeção agora reconhece também propriedades graváveis com valor runtime `NSString`/`String`, mesmo quando o encoding declarado não informa diretamente `NSString`.
- Cada patch fica ligado a um único objeto selecionado. Ativar aplica o novo valor; desativar tenta restaurar a base capturada ao ativar; remover apaga a entrada. Se o app mudar a propriedade no meio do caminho, a alteração externa é preservada para evitar sobrescrita.
- O nome e a definição do patch são salvos em `UserDefaults`. A referência ao objeto continua temporária; após reiniciar ou destruir a view, é necessário selecionar um objeto compatível e vincular novamente antes de ativar.
- O inicializador da dylib agora instala um botão **FLEX** flutuante e arrastável depois que o app hospedeiro fica ativo; tocar no botão abre o painel. A abertura automática do painel foi removida.
- A ponte Objective-C executa leituras/escritas KVC com captura de exceções. O projeto não implementa patching de código, métodos, executável, loader genérico ou bypass e nenhuma IPA foi alterada.

## Pesquisa de referência

As fontes públicas oficiais do FLEX descrevem inspeção/edição de views e valores de objetos, rede, logs, heap, sandbox, bancos SQLite/Realm e `NSUserDefaults`. Não documentam uma função genérica de criação/ativação de patches como recurso do FLEX. Fontes: [README oficial do FLEX](https://github.com/FLEXTool/FLEX), [artigo da Flipboard](https://about.flipboard.com/engineering/flex/) e [Objective-C Runtime da Apple](https://developer.apple.com/documentation/objectivec/objective-c-runtime). A implementação atual é uma ferramenta independente e limitada a patches de propriedades.

## Build e validação

O workflow [#44657623313](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44657623313) passou para a versão anterior, compilando as dylibs arm64 de iPhone e iOS Simulator. A nova atualização de patches nomeados/persistentes está pendente de build CI. XCTest e validação em dispositivo/app hospedeiro real ainda não foram executados.

## Limitações

- A biblioteca não se carrega por conta própria. O app de teste precisa carregá-la; esta entrega não altera nem reempacota IPA.
- XCTest não foi executado e ainda não houve validação visual em aparelho ou app hospedeiro real.
- Os overrides ativos são temporários e aplicados a propriedades Objective-C suportadas de um objeto selecionado; as definições nomeadas permanecem salvas, mas exigem nova vinculação após reinício. Não representam todas as funções do FLEX 3 nem um patcher genérico.
