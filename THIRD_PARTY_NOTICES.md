# Avisos de terceiros

Este pacote contém código-fonte do Arcanjo Dev e referências SwiftPM fixadas. Os binários/pesos dos modelos **não** estão incluídos. Ao resolver dependências, Xcode baixa os projetos-fonte originais e deve manter os respectivos textos de licença no cache/build conforme suas licenças.

| Componente | Versão fixada no projeto | Uso | Licença observada | Fonte |
|---|---:|---|---|---|
| MLX Swift LM | 3.31.4 | Factory, tokenizer/model registry, ChatSession e geração | MIT | [Release e licença](https://github.com/ml-explore/mlx-swift-lm/tree/3.31.4) |
| MLX Swift | 0.31.4 | Runtime MLX/Apple GPU e dependência do MLX Swift LM | MIT | [Tag/licença](https://github.com/ml-explore/mlx-swift/tree/0.31.4) |
| Swift Hugging Face | 0.9.0 | Cliente Hub/downloader para assets públicos do modelo | Apache-2.0 | [Manifesto](https://github.com/huggingface/swift-huggingface/blob/0.9.0/Package.swift), [licença](https://github.com/huggingface/swift-huggingface/blob/0.9.0/LICENSE) |
| Swift Transformers / Tokenizers | 1.3.0 | Tokenizer e chat-template integration usada pelo MLX | Apache-2.0 | [Manifesto](https://github.com/huggingface/swift-transformers/blob/1.3.0/Package.swift), [licença](https://github.com/huggingface/swift-transformers/blob/1.3.0/LICENSE) |
| Qwen3-0.6B convertido para MLX | Transferido sob ação do usuário; revisão/commit do Hub | Modelo recomendado opcional, não embutido | Apache-2.0 no metadado do Hub observado; revalidar na revisão usada | [Modelo MLX](https://huggingface.co/mlx-community/Qwen3-0.6B-4bit), [base Qwen3](https://huggingface.co/Qwen/Qwen3-0.6B) |

A equipe Qwen/Hub marca a conversão MLX como baseada em `Qwen/Qwen3-0.6B` e `license:apache-2.0`. A aplicação não redistribui esses pesos. Licença do runtime não concede direitos sobre pesos, e cada substituição/importação deve ser conferida separadamente.

Outras tecnologias da pesquisa (llama.cpp, ExecuTorch, Core ML, Gemma/LiteRT-LM) **não** são dependências do projeto entregue. Referências de seus repositórios são somente para comparação e não significam que código/binários dessas opções estão no app.

As declarações acima identificam licença dos upstreams consultados, não constituem parecer jurídico. Antes de distribuir uma build, arquive manifests/Package.resolved, notices transitivos e os model cards dos artefatos exatos usados.
