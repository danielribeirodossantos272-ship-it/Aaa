# FLEX Replica — implementação independente

Projeto próprio de inspeção de runtime, inspirado em ferramentas de developer inspection. Não contém código recuperado de `Prefs.dylib` nem reproduz código/ativos do FLEX.

## Recursos implementados

- Busca de classes Objective-C, métodos, selectors, propriedades e type encodings.
- Aba **Views** com a raiz expandida e filhos diretos visíveis, setas separadas da seleção, frames e status hidden/alpha. A `UIWindow` raiz é tratada como contêiner, não como alvo de inspeção.
- Aba **Object** com propriedades/ivars; valores de ivars privados não são dereferenciados. Leituras de propriedades são limitadas a tipos reconhecidos e a valores genéricos em classes do app para reduzir riscos ao inspecionar UIKit.
- Aba **Patches**: cria patches com nome escolhido pelo usuário, salva nome/propriedade/valor substituto em `UserDefaults` e permite ativar, desativar ou remover. Podem existir várias variantes nomeadas para a mesma propriedade, mas somente uma pode ficar ativa por objeto/propriedade. Ao ativar, registra o valor-base atual; ao desativar, restaura esse valor. Se o app tiver alterado a propriedade desde a ativação, a ferramenta preserva o valor atual em vez de sobrescrevê-lo.
- Botão **FLEX** flutuante e arrastável, instalado depois que a dylib entra no processo e o app hospedeiro fica ativo. Tocar nele abre o painel; o painel deixa de surgir automaticamente.
- Entrypoints C `FLEXReplicaInstallFloatingButton()` e `FLEXReplicaShowMenu()` no produto dinâmico `FLEXReplicaCore`.

Os patches são overrides de **valores de propriedades de um único objeto selecionado**. O nome e a definição ficam salvos entre execuções, mas a referência ao objeto é temporária: após reiniciar o app, selecione novamente o objeto compatível, abra **Patches** e toque em **Vincular ao objeto selecionado** antes de ativar. Se o objeto for destruído durante a execução, também será necessário vinculá-lo novamente. Isso não é um patch de executável, de implementação de método ou de código arbitrário, nem uma implementação de paridade total com FLEX 3.

## Uso do painel

1. Com a dylib já carregada no app de teste, espere o botão flutuante **FLEX** aparecer.
2. Abra **Views**. A raiz e os filhos diretos aparecem; use as setas para abrir mais níveis e toque no nome de uma subview (não na `UIWindow` raiz). Use **Editar / salvar patch** para abrir **Object**.
3. Na propriedade editável, digite o novo valor, escolha o **Nome do patch** e toque em **Salvar patch**.
4. O painel muda para **Patches**; a entrada aparece com o nome escolhido e começa desligada. Ative o controle para aplicar o valor, desligue para restaurar o valor-base ou remova a entrada.
5. Depois de reiniciar o app, selecione o objeto novamente, abra **Patches**, vincule a entrada ao objeto e então ative-a.

A biblioteca não se carrega dentro de um app por conta própria. O app hospedeiro ou um loader autorizado ainda precisa carregá-la e assinar os binários corretamente. Esta mudança não altera nem reempacota nenhuma IPA. A variante para iPhone é `dist/ios-device-arm64/libFLEXReplicaCore.dylib`; a variante de simulador é separada.

## Escopo e referências públicas

O README oficial do FLEX descreve inspeção/modificação de views, propriedades/ivars, chamadas de métodos, rede, logs, heap, arquivos do sandbox, SQLite/Realm e `NSUserDefaults`. As fontes oficiais consultadas não documentam um criador/ativador genérico de patches como função do FLEX; esta aba **Patches** é uma implementação original e limitada a overrides reversíveis de propriedades. A exploração do runtime Objective-C é uma camada distinta.

- [FLEX — repositório e README oficial](https://github.com/FLEXTool/FLEX)
- [Introducing Flex — Flipboard Engineering](https://about.flipboard.com/engineering/flex/)
- [Objective-C Runtime — Apple Developer Documentation](https://developer.apple.com/documentation/objectivec/objective-c-runtime)

## Build em macOS/Xcode

```bash
bash Scripts/build_dylib.sh
```

O script produz `dist/ios-device-arm64/libFLEXReplicaCore.dylib` e `dist/ios-simulator-arm64/libFLEXReplicaCore.dylib`, cada variante acompanhada pelo header `FLEXReplicaCore.h`. Para uma IPA de iPhone, somente a variante de dispositivo é aplicável. O app-demo está disponível separadamente via `bash Scripts/build_ios.sh`.

A versão com patches nomeados compilou com sucesso no GitHub Actions [#44662170057](https://github.com/danielribeirodossantos272-ship-it/Aaa/actions/runs/44662170057), gerando variantes arm64 de iPhone e simulador. A correção de expansão/seleção da hierarquia e de leitura segura de ivars está aguardando novo CI. XCTest e validação em iPhone/app hospedeiro real ainda não foram executados.
