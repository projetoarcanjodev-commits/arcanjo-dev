# Segurança e limites

## Controles presentes

- **Modelo não é autoridade:** prompts e texto do modelo não concedem permissões; `ToolRegistry.execute` aplica a allowlist do papel. Tool inexistente ou argumento incompatível falha fechado.
- **Aprovação antes da ação:** gravação/substituição, exclusão e solicitação HTTPS apresentam título e payload (caminho/conteúdo/URL) ao usuário. Recusa não chama o executor. A aprovação é por chamada, não uma autorização geral.
- **Workspace contido:** caminhos absolutos, `..`, separador invertido e caminhos resolvidos fora do workspace são rejeitados; links simbólicos não são seguidos pela listagem. Leitura/escrita tem limite de 512 KiB.
- **Web restrita:** apenas GET para URL HTTPS, rejeita usuário/senha na URL, hosts locais/IPs privados literais e bloqueia redirects; sessão efêmera sem cookies/credential storage/cache. Conteúdo de resposta é limitado a 32 KiB e marcado como dado externo não confiável nos prompts.
- **Validação determinística sem execução de código:** `workspace.validate` aceita JSON e Property List de até 512 KiB. Não executa shell, Swift, Python, JavaScript, testes ou binários.
- **Memória local:** JSONL separado dentro do contêiner sandbox do app. Não há upload automático do objetivo, dos arquivos ou da memória para um LLM comercial. O download de pesos envia apenas tráfego normal ao Hugging Face.

## Ações ausentes por design

Não estão implementados shell, Git, alterações remotas GitHub, deploy, Gmail, WhatsApp, Instagram, login, OAuth ou upload de arquivos a serviços. A UI marca integrações externas como não implementadas. Nenhuma operação de publicação/transação é possível nesta versão.

## Riscos residuais / operação segura

1. **Modelo pequeno e prompt injection:** modelo local pode produzir JSON malformado, código defeituoso ou se deixar influenciar por dados. Resultados de web são marcados como não confiáveis; ainda assim, confira arquivos e conteúdo antes de abrir/usar.
2. **Web/SSRF e DNS:** a checagem atual valida o hostname textual e bloqueia redes privadas conhecidas, mas não faz pinning de DNS/IP no socket. DNS hostil/rebinding, endereços especiais fora da lista ou mudanças de comportamento do sistema ainda são riscos. O GET exige aprovação; não use para URLs sensíveis/internas. Um endurecimento adicional de rede é necessário antes de uso de produção.
3. **Execução real não isolada:** o app não executa código arbitrário. A prévia HTML usa WebKit e deve ser tratada como conteúdo potencialmente não confiável; teste páginas de origem desconhecida com cautela.
4. **Dados em repouso:** conversas, objetivos e saídas de tools ficam em JSONL local. O app não implementa criptografia própria/Keychain para memória; não grave tokens, senhas ou dados pessoais desnecessários. Revise política de backup/retention da distribuição antes de publicar.
5. **Modelo e dependências:** verifique os termos da revisão exata dos pesos, integridade da versão SPM, requisitos de redistribuição e qualquer mudança upstream antes de release. O ZIP não inclui pesos nem credenciais.
6. **Limites de UI:** cada confirmação aprova só o payload mostrado. Se o conteúdo mudar, a ferramenta deve pedir nova aprovação. Não aprove ações cujo caminho, conteúdo ou host você não reconheça.

## Antes de produção

Validar em iPhone real; introduzir proteções de backup/limpeza/exportação para memória; fazer auditoria de DNS/SSRF, tamanho e MIME de respostas Web; definir política de atualização/checksum de pesos; testar prompt injection; fazer revisão de segurança e privacidade. Este documento não é uma certificação de segurança.
