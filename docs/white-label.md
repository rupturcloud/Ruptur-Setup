# Relatório da refatoração

## Implementação

- Entrada principal renomeada para `RupturSetup`; bootstrap baixa o pacote completo
  e verifica falhas antes de executar. O checkout local dispensa downloads.
- Defaults centralizados em `lib/config.sh` e documentados em `.env.example`.
- URLs de marca, suporte, SMTP, rede, origem GitHub e caminho MCP parametrizados.
- Aplicação e worker do atendimento usam templates compartilhados por variante.
- Desbloqueio SQL preservado; `ON_ERROR_STOP` torna falhas SQL observáveis.
- Identificador do container web preservado antes de esperar pelo PostgreSQL,
  evitando executar o patch de marca no container do banco.
- Configurações de marca persistidas pelo modelo Rails; senhas SMTP não são
  exibidas no fluxo do atendimento.
- Downloads dos templates de e-mail substituídos pelo uso dos recursos locais
  da mesma revisão. A atualização seleciona a instância desejada.
- Grafana usa templates para marca, links e endpoint do Node Exporter.
- Recursos Grafana e Zep vêm do checkout; clones redundantes foram removidos.
- Telemetria opcional e desativada por padrão.
- JSONs de exemplo do Typebot mantêm formato válido e recebem variáveis de marca
  e integração editáveis. Configure essas variáveis ao importar os exemplos.
- Copyright original preservado e atribuição do fork acrescentada à licença.

## Integrações externas remanescentes

| Local/função | Origem ou configuração |
|---|---|
| `Setup` | Arquivo de código do GitHub, derivado de `GITHUB_ORG`, `GITHUB_REPO`, `GITHUB_REF` |
| `lib/downloads.sh` | `ASSET_BASE_URL` ou recursos locais |
| `telemetria` | `TELEMETRY_URL`, somente quando habilitada |
| Descoberta de IP | `PUBLIC_IP_URL` |
| `n8n.workflows` | `QUEPASA_WORKFLOWS_URL`, enviado ao container como variável de ambiente |
| Docker | Script de instalação e repositório oficiais |
| Formbricks | Arquivos Cube da versão já referenciada pelo instalador |
| Supabase | Repositório oficial da aplicação |
| `ctop` | Binário de release da ferramenta |
| Portainer/RabbitMQ | APIs dos domínios informados pelo operador |

Os namespaces de imagens de terceiros continuam correspondendo aos fornecedores
reais; não foram substituídos por nomes de imagens inexistentes do fork.

## Limites e continuidade

A ativação funcional das funcionalidades enterprise não foi comprovada em runtime.
As duas flags solicitadas não existiam no código analisado; foram acrescentadas
aos templates como defaults configuráveis. A imagem Mega e o desbloqueio de
configurações foram mantidos. Não há frontend do atendimento nesta árvore.

O mecanismo de marca usa os campos encontrados no
[modelo de configuração da aplicação](https://github.com/chatwoot/chatwoot/blob/develop/config/installation_config.yml)
e no [modelo Rails](https://github.com/chatwoot/chatwoot/blob/develop/app/models/installation_config.rb).
Imagens antigas ou forks podem divergir desse contrato. A validação final de
marca, campanhas e dashboards requer uma implantação de homologação.

Não houve deploy, execução de Docker, envio de e-mails ou publicação de repositório.
A verificação local cobre sintaxe Bash, configuração e geração de stacks. O menu
das demais aplicações continua usando sua implementação existente.

Resultado local: 12 testes passaram, sem testes ignorados, incluindo YAML das
duas variantes, personalização de parceiro, precedência de configuração,
caracteres especiais em segredos, prompts SMTP, falha de download sem perda do
arquivo anterior e renderização Grafana com `jq`. `git diff --check` passou.
Os cinco binários inventariados mantiveram seus hashes SHA-256.

Para instalações existentes, mantenha os valores de rede, diretório de
monitoramento e prefixo da Evolution v1. Os identificadores técnicos de serviços,
bancos e volumes do atendimento foram mantidos para evitar migração desnecessária.
O caminho MCP configurado no Supabase deve ser atualizado nos clientes caso seja
alterado no servidor.

Os binários, dependências, builds e licenças de terceiros foram preservados. A
identidade antiga permanece somente na atribuição original da licença, conforme
a exceção solicitada. Consulte também [o inventário de mídias](media-review.md).
