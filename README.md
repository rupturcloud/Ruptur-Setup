# Ruptur Setup

Instalador Bash de aplicações para Docker Swarm, com identidade, rede, SMTP e
origens de recursos configuráveis. Os dados da Ruptur são valores padrão: cada
parceiro pode utilizar sua própria marca e infraestrutura.

## Executar a partir do checkout

Requisitos para instalação: Debian/Ubuntu, Bash 4.3+, acesso root e as dependências dos
instaladores escolhidos. O menu pode instalar serviços e alterar o servidor.
Use uma VPS destinada a essa instalação. A geração de modelos e a validação não
exigem root ou Docker; a geração de chave aleatória usa OpenSSL.

O modo de instalação prepara as dependências básicas ausentes via `apt-get`.
Ajuda, validação e renderização saem antes dessa etapa. O bootstrap não executa
atualizações completas do sistema operacional.

```bash
cp .env.example .env
chmod 600 .env
# Edite .env com os dados do seu ambiente.
bash Setup --check-config
bash Setup
```

`Setup` inicia `RupturSetup` no checkout local. Não baixe somente o arquivo
`RupturSetup`: ele depende de `lib/`, `modules/`, `templates/` e `Extras/`.

Quando distribuído isoladamente, `Setup` baixa o pacote completo do GitHub.
A origem padrão é `rupturcloud/ruptur-setup`, referência `main`. O fork precisa
estar publicado nessa origem antes de usar o bootstrap remoto. A publicação
não faz parte desta alteração.

```bash
bash Setup --org minha-organizacao --repo meu-instalador --ref minha-versao
```

Na execução remota, use `--org`, `--repo`, `--ref` ou as variáveis `GITHUB_*`
para escolher o pacote **antes** do download. O `.env` é lido pelo instalador
depois do download; passe `--config /caminho/absoluto/cliente.env` para um arquivo
externo. No checkout, o arquivo padrão é `.env` ao lado de `RupturSetup`.

## Configuração de parceiros

```bash
bash RupturSetup --config cliente.env \
  --domain https://cliente.example \
  --brand "Minha Empresa" \
  --chat-brand "Meu Atendimento" \
  --network cliente-net \
  --smtp-host smtp.cliente.example \
  --smtp-user mail@cliente.example
```

Precedência: argumentos > ambiente > arquivo `.env` > defaults. Nos fluxos
interativos, os prompts mostram o valor efetivo; Enter o mantém, e uma resposta
o substitui para aquela instalação. As aplicações do menu continuam solicitando
os seus dados específicos. Os prompts SMTP usam a configuração central.

O arquivo aceita `CHAVE=valor`, comentários em linhas próprias e valores entre
aspas simples ou duplas. Valores são literais: não use `export`, interpolação
`${VAR}`, comandos Bash ou comentários ao final de um valor. Chaves desconhecidas
são rejeitadas. Senhas não são executadas como código. O arquivo não é carregado
com `source`.

| Configuração | Default |
|---|---|
| `BASE_URL` | `https://ruptur.cloud` |
| `BRAND_NAME` / `CHAT_BRAND_NAME` | `Ruptur` / `Ruptur-Chat` |
| `SUPPORT_EMAIL` | `contato@ruptur.cloud` |
| `SMTP_FROM_EMAIL` | `ruptur.cloud@gmail.com` |
| `SMTP_USERNAME` | Remetente efetivo, se não informado |
| `SMTP_HOST` / `SMTP_PASSWORD` | Solicitados; sem credenciais embutidas |
| `SMTP_PORT` | `587` |
| `DOCKER_NETWORK` | `ruptur-net` |
| `MONITOR_DIR` | `/opt/monitor-ruptur` |
| `SUPABASE_MCP_PATH` | `ruptur-setup` |

`BASE_URL` aceita HTTP/HTTPS com hostname, sem caminho ou porta. O domínio do
atendimento pode ser configurado separadamente em `CHAT_DOMAIN`. O host SMTP é
independente do usuário e do remetente. Se um parceiro informar outro remetente
e não especificar usuário SMTP, o login passa a ser o remetente dele.

A rede gravada em `dados_vps` continua sendo utilizada por instalações existentes.
`DOCKER_NETWORK` é o fallback para redes ainda não definidas. Para Evolution v1,
`EVOLUTION_V1_PREFIX` pode receber o identificador de serviço/volumes já existente.
Defina `MONITOR_DIR` com o caminho usado por instalações de monitoramento existentes.
Nenhum volume ou banco existente é renomeado automaticamente.

## Ruptur-Chat

As variantes `standard` e `mega` usam, respectivamente, `CHATWOOT_IMAGE` e
`CHATWOOT_MEGA_IMAGE`. Os defaults preservam as imagens `chatwoot/chatwoot:latest`
e `sendingtk/chatwoot:latest`; para reprodutibilidade, configure uma tag ou digest
que tenha sido validado no seu ambiente.

Os modelos incluem `CW_ENABLE_ENTERPRISE=true` e `ENTERPRISE_TOKEN=true` na
aplicação e no worker. Esses defaults são configuráveis. O suporte a eles depende
da imagem: incluí-los **não comprova** ativação de recursos enterprise. O SQL de
desbloqueio de `installation_configs` foi preservado. Campanhas e dashboards
premium precisam de validação funcional na imagem implantada.

Após a preparação do banco, o instalador aplica nome da instalação, marca,
URLs e suporte via modelo `InstallationConfig`. Os e-mails usam a configuração
de marca da aplicação, com fallback configurável. Não há código-fonte do frontend
incluído neste repositório; logos e eventuais marcas compiladas na imagem dependem
de seus recursos de personalização. Atualizações da imagem podem alterar esse
comportamento.

Para atualizar os templates de e-mail de uma instância, use os comandos do menu
`chatwoot.mail [instancia]` ou `chatwoot.n.mail [instancia]`. A operação seleciona
o serviço correspondente, faz backup dos templates e não remove containers de
outras instalações.

### Gerar uma stack sem instalar

Configure `SMTP_HOST` e `SMTP_PASSWORD` em `.env`. Informe a senha do PostgreSQL
por ambiente; `CHAT_SECRET_KEY` é opcional, e será gerada quando ausente.

```bash
read -rs -p 'Senha PostgreSQL: ' CHAT_POSTGRES_PASSWORD; echo
export CHAT_POSTGRES_PASSWORD
bash RupturSetup --render-chatwoot cliente.rendered.yaml \
  --variant mega --instance cliente
unset CHAT_POSTGRES_PASSWORD
```

O arquivo contém segredos e é criado com permissão `600`. Aspas e cifrões são
escapados para YAML/Compose. Renderizar não cria bancos, volumes, redes ou
serviços; os recursos externos devem existir antes de um deploy manual.

## Organização e validação

- `lib/config.sh`: configuração, argumentos, prompts e validação.
- `lib/downloads.sh`: downloads e resolução de recursos.
- `lib/templates.sh`: renderização literal, sem `eval`.
- `lib/chatwoot.sh`, `modules/chatwoot.sh`: configuração e instalação do atendimento.
- `lib/grafana.sh`, `templates/grafana/`: modelos do monitoramento.
- `RupturSetup`: menu e demais instaladores existentes.

Telemetria do instalador fica desativada por padrão. Para habilitá-la, configure
`TELEMETRY_ENABLED=true` e `TELEMETRY_URL`; ela envia IP, ferramenta e estado.
Isso não controla a telemetria própria de imagens de terceiros.

Os workflows opcionais Quepasa exigem `QUEPASA_WORKFLOWS_URL` apontando para um
diretório HTTPS com os arquivos esperados. Não foi inventado um repositório de
workflows inexistente na organização do fork.

Validação local, sem Docker:

```bash
npm ci --prefix tests
npm test --prefix tests
```

No Windows, os testes usam Git Bash; em outros ambientes, `bash` no PATH.
`BASH_BIN` permite informar outro executável. Node.js e o parser YAML são
dependências **dos testes**, não da instalação Bash.
O teste de renderização Grafana exige `jq` no PATH e é sinalizado como ignorado
quando essa ferramenta não está disponível.

Veja [o relatório de implementação](docs/white-label.md),
[o inventário de mídias](docs/media-review.md) e
[a proposta de MCP](docs/mcp.md). A licença MIT e as atribuições estão em
[LICENSE.txt](LICENSE.txt).
