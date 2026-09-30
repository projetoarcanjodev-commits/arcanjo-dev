# Relatório de testes

**Data:** 30 de setembro de 2026. **Ambiente:** Manus Sandbox Linux. O ambiente não possui Swift, `xcodebuild`, `xcrun`, Xcode ou dispositivo iOS. A lista de dispositivos autorizados desta sessão continha apenas o Sandbox; por isso não foi possível realizar compilação/instalação Apple. Os resultados abaixo não afirmam que o app já compilou.

## Executado com sucesso

| Verificação | Resultado observado |
|---|---|
| `./scripts/test-static.sh` | **10 testes Python passaram** (`unittest`). Incluem papéis, pipeline, tools/schemas, dependências, docs, runtime MLX, ausência de modelos/secrets óbvios e controles de segurança. |
| `python3 scripts/generate-xcodeproj.py` | Gerou `project.pbxproj` com **19 fontes do app**, 1 fonte XCTest e 4 dependências SwiftPM diretas versionadas. |
| Parser Swift Tree-sitter | **20 arquivos Swift** do app/test target sem erros gramaticais. Isso não é type-check, linking nem compilação. |
| Scheme compartilhado | XML do `ArcanjoDev.xcscheme` parseado com sucesso. |
| Projeto OpenStep | `pbxproj` carregado com parser Python `pbxproj`; foram inspecionados os targets `ArcanjoDev` e `ArcanjoDevTests`. |
| Links locais Markdown | Links relativos dos `.md` existentes foram verificados; nenhum destino local quebrado. |

`plutil` não está instalado no Sandbox; o projeto foi validado pelo parser OpenStep independente. O gerador e os testes estáticos rodam com Python padrão; o parser Tree-sitter foi usado somente para esta checagem, não é dependência do app.

## XCTest incluído, pendente de executar no Xcode

O target `ArcanjoDevTests` contém cinco casos:

- `testToolWriteRequiresApprovalAndWritesOnlyInsideWorkspace`
- `testDeniedApprovalPreventsWrite`
- `testWorkspaceValidateChecksJSONAndRejectsExtraArguments`
- `testPlannerExecutorVerifierCompletesWithLocalWorkspaceTool`
- `testMemoryBucketsAreIndependent`

Os providers roteirizados aparecem somente no target XCTest. O ponto de entrada do app instancia `LocalRuntimeFactory`, que seleciona `MLXLocalModelProvider`; não existe fallback de resposta pré-programada no produto.

## Não executado / não demonstrado

- `xcodebuild build` / `xcodebuild test`, type-check Swift, linkagem ou resolução real de dependências SwiftPM.
- Assinatura, instalação, lançamento, UI ou inferência em iPhone/simulador.
- Download do modelo, uso de cache/offline, RAM, tokens/s, qualidade em português brasileiro ou tool-calling do Qwen no hardware final.
- Compilação/execução de projetos de usuário, execução de suites genéricas, publicação/deploy, Git remoto e integrações comerciais.

Para fechar a validação Apple, siga [`BUILD.md`](BUILD.md) em Mac com Xcode 26+ recomendado e rode os comandos de resolução, build e XCTest. Depois, acrescente aqui versões de Xcode/iOS, aparelho, logs e resultados; não marque itens pendentes como aprovados sem evidência.
