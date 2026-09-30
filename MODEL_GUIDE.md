# Guia do modelo local

## Runtime e versão

A primeira implementação concreta usa **MLX Swift LM 3.31.4** com MLX Swift 0.31.4, Hugging Face Swift 0.9.0 e Swift Transformers 1.3.0. São dependências de SwiftPM do projeto Xcode, não serviços de geração pagos. Os manifests dos pacotes MLX declaram iOS 17. MLX Swift LM fornece `LLMModelFactory`, `ChatSession`, history rehydration e geração streaming; a integração iOS tem exemplo oficial. Consulte as versões e comparação em [`docs/COMPONENT_RESEARCH.md`](docs/COMPONENT_RESEARCH.md).

## Modelo recomendado

- **ID:** `mlx-community/Qwen3-0.6B-4bit`
- **Formato/runtime:** pesos MLX safetensors; Qwen3 0,6B, quantização 4-bit, chat template Qwen3.
- **Origem/licença:** repositório MLX informa conversão de `Qwen/Qwen3-0.6B`; a API do Hub registra tag de licença Apache-2.0 para o artefato consultado. Confirme a ficha/revisão atual antes de redistribuir.
- **Tamanho observado:** metadado do Hub registrou `usedStorage` 682.323.786 bytes no modelo observado (aprox. 682 MB decimal). Cache/cópias e pico de RAM somam custos adicionais.
- **Idioma/capacidade:** ficha Qwen declara 100+ idiomas/dialetos e contexto de 32.768 tokens. Não há teste PT-BR nem benchmark de coding/tool-calling para o Arcanjo. O desempenho em iPhone, RAM, consumo e temperatura dependem do hardware, contexto e estado térmico.
- **Tamanho de contexto:** o provider mantém até seis mensagens recentes, preserva a primeira solicitação, limita entrada em caracteres e saída em até 1.024 tokens. São guardrails iniciais, não um limite de RAM certificado.

O provider envia `/no_think` no system context do Qwen3 e implementa protocolo próprio de tool-call em JSON; ele não despacha chamadas nativas arbitrárias do MLX. A resposta é validada e executada apenas pela aplicação e pelo `ToolRegistry`.

## Carregar, importar e trocar

1. Compile e abra o app no Xcode.
2. Toque **Baixar recomendado** para transferir o modelo público e carregá-lo via Hugging Face Hub. O download só começa após o toque; é necessária internet na primeira obtenção/cache.
3. Alternativamente, toque **Importar pasta** e selecione o diretório completo de um modelo convertido para MLX. O app copia a pasta para `Documents/ArcanjoDev/Models`; necessita de `config.json`, tokenizer compatível e pesos que MLX Swift LM reconheça.
4. Para voltar ao Qwen recomendado, toque **Baixar recomendado** novamente. O identificador ativo fica salvo em `active-model.txt`; assets do Hub ficam no cache local do app. Se o sistema limpar o cache, baixe novamente.

**Não** selecione `.gguf` ou arquivo de peso isolado: o importador desta versão aceita somente pasta MLX completa. Uma arquitetura não suportada pelo MLX Swift LM falha ao carregar em vez de usar um fallback fictício.

## Alternativas pesquisadas

- **llama.cpp + GGUF:** bom candidato futuro para formatos GGUF e maior variedade, com XCFramework oficial para iOS. Tag/artefato e licenças dos pesos precisam ser fixados. GGUF é formato, não licença ou quantização por si só.
- **ExecuTorch + Qwen3-0.6B `.pte`/XNNPACK:** exemplo oficial de exportação quantizada e app mobile; API Swift iOS foi descrita como experimental e requer pipeline de exportação/linkagem.
- **Core ML:** alternativa nativa se um checkpoint converter com operações compatíveis.
- **Gemma 4 E2B + LiteRT-LM:** candidato para teste em iPhones recentes; a integração Swift/iOS consultada está em Early Preview. Métricas do Google em iPhone 17 Pro não se aplicam universalmente.

## Licença e redistribuição

Runtime, conversão e pesos são licenças distintas. O pacote **não inclui pesos**. Embora o artefato Qwen3-0.6B-4bit consultado esteja marcado Apache-2.0, revise a licença e model card do ID/commit efetivamente carregado antes de redistribuir. Mais detalhes em [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) e pesquisa com fontes oficiais em [`docs/COMPONENT_RESEARCH.md`](docs/COMPONENT_RESEARCH.md).

## Fontes oficiais

- [MLX Swift LM 3.31.4 — manifesto de runtime/plataformas](https://github.com/ml-explore/mlx-swift-lm/blob/3.31.4/Package.swift)
- [Exemplo oficial LLMEval iOS](https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/LLMEval/README.md)
- [Registry de modelos MLX LM — Qwen3 0.6B 4-bit](https://github.com/ml-explore/mlx-swift-lm/blob/3.31.4/Libraries/MLXLLM/LLMModelFactory.swift)
- [Model card oficial Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B)
- [Conversão MLX Qwen3-0.6B-4bit](https://huggingface.co/mlx-community/Qwen3-0.6B-4bit)
- [Metadados do Hub consultados para bytes usados, quantização e licença](https://huggingface.co/api/models/mlx-community/Qwen3-0.6B-4bit)
- [API ChatSession e histórico](https://github.com/ml-explore/mlx-swift-lm/blob/3.31.4/Libraries/MLXLMCommon/ChatSession.swift)
