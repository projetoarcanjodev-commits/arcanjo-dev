# Próximos passos

## Bloqueadores antes de uso de produção

1. Resolver dependências e compilar o scheme no Xcode recomendado; corrigir incompatibilidades que só um toolchain Apple consegue detectar.
2. Rodar XCTest em macOS/simulador e testar instalação, download, reinício, reload de cache e memória no iPhone físico mínimo suportado.
3. Medir tokens/s, primeiro token, pico de RAM, armazenamento, bateria, temperatura sustentada e encerramentos por jetsam para tarefas PT-BR representativas.
4. Medir precisão do planner, JSON, chamadas de tools, ciclos de correção e qualidade de código. Adicionar corpus de regressão em português e testes adversariais.
5. Endurecer o fetch contra DNS rebinding/SSRF, limitar MIME/tempo/tamanho por streaming e cobrir testes de host privado/redirects.
6. Definir política de retenção, exportação, limpeza e proteção de backup para memória; projetar segregação de projetos e recuperação de workspace.

## Evolução funcional

- Melhorar fluxo incremental de eventos da inferência, cancelamento efetivo, progress de download e tratamento de memória insuficiente.
- Adicionar testes determinísticos locais para artefatos web e validadores específicos por tecnologia sem executar comandos arbitrários por padrão.
- Avaliar opção de runtime/adapter `llama.cpp` para GGUF ou `Core ML` para modelos convertíveis, sempre atrás do protocolo atual e com licença/versionamento.
- Reavaliar modelo maior, como Gemma 4 E2B via LiteRT-LM ou Qwen atualizado, somente após validar runtime estável, arquitetura e custo em aparelho.
- Implementar Git por biblioteca nativa e adapter com preview/diff e aprovação por operação.
- Implementar GitHub/Netlify via APIs oficiais, OAuth/Keychain, permissões mínimas, preview exato e confirmação antes de qualquer publicação.
- Gmail/WhatsApp Business/Instagram: escopos oficiais, políticas, aprovação individual e proteção de credenciais; nenhum endpoint presumido.
- Especialistas externos (OpenAI, Anthropic, Manus): somente quando houver credencial configurada pelo usuário, interface documentada, consentimento claro e fluxo de dados revisado.
- Explorar delegação paralela real e recuperação de contexto/memória sem perder isolamento por agente.

Nenhum item nesta lista está anunciado como já funcional.
