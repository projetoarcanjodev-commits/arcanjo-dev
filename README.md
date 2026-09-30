# Arcanjo Dev

**Arcanjo Dev** é um protótipo funcional de agente pessoal nativo para iPhone, offline-first após instalar/baixar um modelo. Ele não é apenas uma tela de chat: implementa planner, executor, perfis de agente, ferramentas locais, memória, verificação e correção limitada. A inferência real usa MLX Swift LM. O ZIP não inclui pesos de modelo.

> A fonte foi criada no Sandbox Linux, que não dispõe de Swift, Xcode ou iPhone. Os testes estáticos executados aqui não substituem compilação XCTest nem validação de inferência em aparelho. Consulte [`TEST_REPORT.md`](TEST_REPORT.md) e [`BUILD.md`](BUILD.md) antes de tratar esta versão como pronta para produção.

## O que funciona

- **Inferência local real:** provider MLX Swift LM e download sob ação explícita de Qwen3-0.6B-4bit. Depois do download/cache, a geração ocorre no dispositivo. Também é possível importar uma pasta completa de modelo no formato MLX compatível com o loader.
- **Ciclo de execução:** planner gera plano JSON; agentes especializados trabalham sequencialmente; ferramentas operam no workspace; verifier examina relatórios e arquivos listados; o orquestrador pode fazer até duas rodadas de correção conforme o plano.
- **Dez perfis:** Pesquisador, Programador, Web, Designer, Testador, Revisor, DevOps, Integrações, Memória e Segurança. Cada papel recebe allowlist própria; todos compartilham o runtime configurado nesta versão.
- **Ferramentas executáveis locais:** listar/ler/gravar/excluir dentro do workspace, buscar uma URL HTTPS pública por GET e validar sintaxe JSON/Property List sem executar código. Gravação, exclusão e acesso Web pedem aprovação antes da ação.
- **Workspace e prévia:** workspace separado no contêiner do app; arquivos HTML podem ser abertos em prévia local com WKWebView.
- **Memória local:** conversas, projetos, longo prazo, decisões, resultados de tools e execuções são armazenados em categorias distintas. A memória durável pode ser apresentada como contexto a planejador/agentes.
- **Interface de providers externos:** contratos e catálogo existem para OpenAI, Anthropic/Claude, Manus e outros, mas **não há adaptador/API/credencial ativos**.

## Começar

1. Abra `ArcanjoDev.xcodeproj` no Xcode de um Mac; siga [`BUILD.md`](BUILD.md).
2. Defina um Team de assinatura para executar em iPhone e compile o target `ArcanjoDev`.
3. Na aba **Agente**, toque **Baixar recomendado**. A primeira obtenção precisa de internet e baixa os arquivos do Hugging Face. O peso-modelo não está no ZIP.
4. Aguarde “Modelo local pronto”, digite o objetivo e inicie **Planejar e executar**.
5. Examine cada pedido de aprovação, especialmente o conteúdo/path completo, antes de permitir. Veja os artefatos em **Workspace** e **Prévia**.

A versão consultada da conversão ocupa cerca de **682 MB** segundo os metadados do Hub; o uso de disco/RAM durante a inferência é maior e depende do contexto/aparelho. Modelos no cache ficam no contêiner privado do app e podem ser removidos pelo sistema quando faltar espaço; sem cache, a nova carga requer rede. [Detalhes e fonte](MODEL_GUIDE.md).

## Limites importantes

- Requer iPhone com Apple Silicon e iOS 17+ para o runtime escolhido; desempenho e RAM não foram medidos neste ambiente. A compatibilidade real por geração de iPhone ainda precisa ser estabelecida.
- O modelo 0.6B quantizado é um **ponto inicial pequeno**, não promessa de qualidade para programação complexa, português brasileiro ou chamadas de ferramenta confiáveis. O app limita geração/contexto para reduzir risco de memória, mas é preciso medir em hardware real.
- `workspace.validate` valida apenas JSON e Property List. Não compila Swift, não executa testes arbitrários, não roda navegador automatizado nem lança shell.
- O verifier é uma segunda análise do modelo com evidência da listagem de arquivos. Ele não é compilador, test runner ou revisão humana. Resultado “passou” não prova execução de software.
- Não há Git/libgit2, GitHub, Netlify, Gmail, WhatsApp Business, Instagram/Meta, publicação/deploy, agentes em paralelo, execução de comandos ou provedor externo implementados. Interfaces externas estão marcadas como não implementadas.
- A única ferramenta web atual é um GET HTTPS explicitamente aprovado para URL informada pelo agente; não há busca geral por motor, login, scraping autenticado ou envio de conteúdo.

## Documentação

- [`BUILD.md`](BUILD.md) — requisitos, build, testes Xcode e instalação no iPhone.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — componentes e fluxo de execução.
- [`SECURITY.md`](SECURITY.md) — permissões, aprovações e riscos residuais.
- [`MODEL_GUIDE.md`](MODEL_GUIDE.md) — escolha do runtime/modelo e troca/importação.
- [`docs/COMPONENT_RESEARCH.md`](docs/COMPONENT_RESEARCH.md) — comparação de runtimes/modelos com fontes oficiais.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — dependências, versões e licenças verificadas.
- [`ROADMAP.md`](ROADMAP.md) — próximas etapas.
- [`TEST_REPORT.md`](TEST_REPORT.md) — comandos executados e o que permanece sem validação.
- [`docs/source/Arcanjo_Dev_para_Manus/PROMPT_MISSAO_MANUS.md`](docs/source/Arcanjo_Dev_para_Manus/PROMPT_MISSAO_MANUS.md) — prompt original recebido.

Nome oficial: **Arcanjo Dev**.
