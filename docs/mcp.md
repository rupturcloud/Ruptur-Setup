# MCP do Ruptur Setup

## Situação verificada

O instalador contém uma rota MCP para o Supabase Studio e uma implantação de
webhook MCP do n8n. Esses recursos pertencem às aplicações implantadas. Eles
não implementam um servidor MCP que administra o próprio instalador.

A rota do Supabase é configurável por `SUPABASE_MCP_PATH`:
`https://DOMINIO/mcp/CAMINHO/HASH`. Trocar esse caminho altera a URL dos clientes;
não transforma o serviço em um MCP do Ruptur Setup. A configuração herdada dessa
rota usa CORS e um caminho com hash, sem autenticação adicional nessa rota Kong.

Não foi implementado nem publicado um MCP próprio nesta refatoração. A pergunta
de viabilidade foi tratada como arquitetura, mantendo o escopo aprovado do
instalador.

## Arquitetura proposta

Um servidor MCP pode expor ferramentas tipadas sobre os módulos e comandos do
instalador, com três grupos de capacidades:

| Ferramenta proposta | Responsabilidade |
|---|---|
| `list_applications` | Listar aplicações e parâmetros suportados |
| `validate_configuration` | Validar entradas com a mesma regra usada pela CLI |
| `prepare_installation` | Gerar um plano e stacks para revisão |
| `get_service_status` | Consultar Docker/Portainer do ambiente autorizado |
| `apply_installation` | Executar um plano específico após autorização |

Os comandos `--check-config` e `--render-chatwoot` já são pontos de integração
sem efeitos sobre infraestrutura. O restante do menu ainda é interativo; um MCP
com instalação completa exigirá mais extração de módulos e comandos sem prompts.

Uma primeira versão pode usar transporte local stdio. Uma versão remota precisará
de autenticação, autorização por ambiente/cliente, separação de segredos e registro
de operações. Não deve expor execução arbitrária de shell nem usar apenas um
caminho secreto como autorização para administrar servidores.

Referência: [conceitos oficiais de servidores MCP](https://modelcontextprotocol.io/docs/learn/server-concepts).
