# Build, testes e instalação

## Ambiente necessário

- Mac com Xcode e ferramentas de linha de comando SwiftPM.
- Target iOS **17.0+**. Para compatibilidade com toolchain/macros SwiftSyntax das dependências, **Xcode 26 ou mais novo é recomendado**. O manifesto MLX Swift LM 3.31.4 declara Swift tools 6.1 e iOS 17; o projeto usa Swift 5 language mode para o app.
- iPhone Apple Silicon com armazenamento livre para o modelo (aprox. 682 MB no snapshot consultado, mais cache e outros arquivos). O ZIP não carrega pesos.
- Team Apple Developer pessoal/gratuito para instalação local e assinatura no dispositivo. Publicar na App Store não é parte desta missão.

## Abrir e compilar

1. Descompacte o pacote final e, em Terminal no diretório raiz, rode:

   ```bash
   python3 scripts/generate-xcodeproj.py
   ```

   O gerador recria `ArcanjoDev.xcodeproj/project.pbxproj` e o scheme compartilhado. As dependências diretas estão fixadas por versão: `mlx-swift-lm` 3.31.4, `mlx-swift` 0.31.4, `swift-huggingface` 0.9.0 e `swift-transformers` 1.3.0. A resolução transitiva pode gravar o respectivo `Package.resolved` no Xcode.

2. Abra `ArcanjoDev.xcodeproj` no Xcode. Aguarde **Resolve Package Dependencies** terminar; a primeira compilação precisa de internet para buscar fontes/macros/frameworks SwiftPM.
3. Selecione o scheme `ArcanjoDev`. Em **Signing & Capabilities**, escolha seu Team e, se necessário, altere `com.arcanjodev.app` para um Bundle Identifier único.
4. Selecione um simulador iOS ou um iPhone conectado e pressione **Run**. A inferência deve ser validada em iPhone físico; execução/velocidade no simulador não é promessa deste projeto.

Exemplos de comandos (ajuste o nome do simulador a um que exista no seu Xcode):

```bash
xcodebuild -resolvePackageDependencies \
  -project ArcanjoDev.xcodeproj -scheme ArcanjoDev

xcodebuild test \
  -project ArcanjoDev.xcodeproj -scheme ArcanjoDev \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild build \
  -project ArcanjoDev.xcodeproj -scheme ArcanjoDev \
  -destination 'generic/platform=iOS'
```

Para executar em iPhone conectado: selecione o dispositivo no Xcode, configure Team/assinatura e clique em Run. O primeiro pareamento pode pedir que o aparelho confie no desenvolvedor. Nenhuma etapa exige chave API comercial.

## Rodar testes disponíveis no pacote

No macOS ou Linux, os testes estáticos usam Python padrão:

```bash
./scripts/test-static.sh
```

Eles verificam arquivos/documentos obrigatórios, papéis, pipeline, presença do provider, schemas/controles de segurança e ausência de pesos/secrets óbvios. No Mac, `xcodebuild test` executa os casos XCTest para gravação aprovada/negada, isolamento do workspace, validação local, memória e fluxo Planner→Executor→Verifier.

Este arquivo não afirma que XCTest ou build iOS já passaram: veja [`TEST_REPORT.md`](TEST_REPORT.md), que distingue resultados observados no Sandbox Linux dos comandos pendentes de rodar em Mac/iPhone.

## Baixar ou trocar o modelo

- Ação inicial **Baixar recomendado**: inicia pedido explícito ao Hub e carrega `mlx-community/Qwen3-0.6B-4bit`. O indicador atual é indeterminado; não há percentual de download.
- **Importar pasta**: selecione uma pasta de modelo completa em formato MLX. O app copia-a para `Documents/ArcanjoDev/Models` e só então tenta carregá-la. O diretório precisa ter `config.json`, tokenizer e pesos reconhecidos pela versão MLX.
- GGUF, arquivo de peso isolado e modelos de arquiteturas que não estejam implementadas no MLX Swift LM atual não são suportados pelo importador. A política do app persiste o modelo ativo.
- Para mudar de volta ao Qwen recomendado, toque novamente **Baixar recomendado**. O runtime usa cache do app no Hugging Face; cache pode ser removido pelo iOS sob pressão de espaço.

## Ferramentas e rede

Não é necessário configurar token para o modelo público indicado. A inferência permanece local depois que os assets estiverem disponíveis. A chamada inicial ao Hugging Face é uma transferência de artefatos; `web.fetch` faz chamadas GET HTTPS somente quando o usuário aprova. Os contratos de OpenAI/Anthropic/Manus não têm secrets, endpoints ou tela de configuração porque não são implementados nesta versão.
