# BestPlayer 8K — Infraestrutura Nginx

Reverse proxy para a aplicação BestPlayer 8K, gerenciado via Docker Compose.

**Arquitetura:**
```
Internet
    │
    ▼
nginx:1.25-alpine  (porta 80 e 443 — IPv4 e IPv6)
    ├── /api/*  →  backend NestJS  (127.0.0.1:3000)
    └── /*      →  frontend Next.js (127.0.0.1:3001)
```

---

## Pré-requisitos

- Docker e Docker Compose instalados
- Backend e frontend já rodando (portas 3000 e 3001 no host)
- Certificado SSL gerado via Let's Encrypt em `/etc/letsencrypt`
- `make` disponível no servidor

---

## Primeira vez — instalação do zero

### 1. Clonar o repositório

```bash
git clone https://github.com/daniloasantos/BestPlayer8k-Nginx.git /opt/bp8k/infra
cd /opt/bp8k/infra
```

### 2. Gerar o certificado SSL (se ainda não tiver)

O nginx depende dos certificados antes de subir. Gere com o Certbot:

```bash
# Instalar certbot (se necessário)
apt install -y certbot

# Gerar certificado — substitua pelo seu domínio
certbot certonly --standalone \
  -d bestplayer8k.cloud \
  -d www.bestplayer8k.cloud
```

Os certificados serão salvos em `/etc/letsencrypt/live/bestplayer8k.cloud/`.

> **Atenção:** o Certbot usa a porta 80 durante a geração. Se o nginx já estiver rodando, pare-o antes com `make down`.

### 3. Ajustar o domínio na configuração

Edite `nginx/conf.d/default.conf` e substitua todas as ocorrências de `bestplayer8k.cloud` pelo seu domínio:

```bash
sed -i 's/bestplayer8k.cloud/seudominio.com/g' nginx/conf.d/default.conf
```

### 4. Subir o nginx

```bash
make up
```

### 5. Verificar se está saudável

```bash
make ps
```

A saída esperada é `(healthy)` na coluna STATUS:

```
NAME           IMAGE               STATUS
nginx-server   nginx:1.25-alpine   Up X seconds (healthy)
```

### 6. Testar o acesso

```bash
curl -I https://seudominio.com
# HTTP/2 200
```

---

## Manutenção do dia a dia

### Recarregar configuração após editar um arquivo

Após qualquer alteração em `nginx/conf.d/default.conf` ou `nginx/nginx.conf`, aplique sem derrubar o serviço:

```bash
# Testa a sintaxe primeiro
make test

# Aplica sem downtime
make reload
```

> `make reload` só aplica se a sintaxe estiver correta. Em caso de erro, o nginx continua rodando com a configuração anterior.

### Ver logs em tempo real

```bash
make logs
```

### Ver status do container

```bash
make ps
```

### Parar e subir

```bash
make down
make up
```

### Reiniciar o container

```bash
make restart
```

---

## Modo de manutenção

Exibe a página de manutenção para todos os visitantes sem derrubar os containers do backend e frontend.

### Ativar

```bash
make maintenance-on
```

O site passa a responder 503 com a página `nginx/html/maintenance.html` para todas as rotas (`/` e `/api/*`).

### Desativar

```bash
make maintenance-off
```

O site volta ao normal imediatamente.

### Como funciona internamente

O modo de manutenção **não altera nenhum arquivo de configuração**. Ele funciona criando um arquivo flag em um volume Docker exclusivo (`nginx_flags`). O nginx verifica a existência desse arquivo a cada request:

```
flag existe  →  retorna 503 + página de manutenção
flag ausente →  comportamento normal
```

Isso garante que:
- A configuração nunca é sobrescrita por engano
- O flag persiste entre restarts do container
- Ativar/desativar é instantâneo (sem reload de configuração)

---

## Renovação de certificado SSL

O Let's Encrypt emite certificados com validade de 90 dias. Para renovar:

```bash
# Para o nginx para liberar a porta 80
make down

# Renova o certificado
certbot renew

# Sobe o nginx novamente
make up
```

Para automatizar, adicione ao cron do servidor:

```bash
crontab -e
```

```
# Renovação automática às 3h do dia 1 e 15 de cada mês
0 3 1,15 * * docker stop nginx-server && certbot renew --quiet && docker start nginx-server
```

---

## Estrutura dos arquivos

```
infra/
├── docker-compose.yml          # Definição do serviço nginx
├── Makefile                    # Comandos de operação
├── .env.example                # Referência de variáveis de ambiente
├── .gitignore
└── nginx/
    ├── nginx.conf              # Configuração global (contexto http)
    ├── conf.d/
    │   └── default.conf        # Virtual hosts, SSL, proxy, manutenção
    └── html/
        └── maintenance.html    # Página exibida no modo de manutenção
```

### Volumes montados no container

| Arquivo/pasta no host | Destino no container | Permissão |
|---|---|---|
| `./nginx/nginx.conf` | `/etc/nginx/nginx.conf` | somente leitura |
| `./nginx/conf.d/` | `/etc/nginx/conf.d/` | somente leitura |
| `./nginx/html/` | `/opt/nginx/html/` | somente leitura |
| `/etc/letsencrypt` | `/etc/letsencrypt` | somente leitura |
| volume `nginx_flags` | `/var/run/nginx-flags/` | leitura e escrita |

---

## Referência de comandos

| Comando | O que faz |
|---|---|
| `make up` | Sobe o nginx |
| `make down` | Para e remove o container |
| `make restart` | Reinicia o container |
| `make reload` | Recarrega a config sem downtime |
| `make test` | Testa a sintaxe do nginx |
| `make logs` | Logs em tempo real |
| `make ps` | Status do container |
| `make maintenance-on` | Ativa modo de manutenção |
| `make maintenance-off` | Desativa modo de manutenção |

---

## Git Flow

Este repositório usa o fluxo padrão do git-flow:

| Branch | Finalidade |
|---|---|
| `master` | Produção — só recebe merges de `release/*` e `hotfix/*` |
| `develop` | Desenvolvimento — branch padrão para novas alterações |
| `feature/*` | Novas funcionalidades |
| `bugfix/*` | Correções em desenvolvimento |
| `release/*` | Preparação de versão para produção |
| `hotfix/*` | Correções urgentes direto em produção |

### Fluxo para alterações de configuração

```bash
# 1. Criar branch de feature a partir do develop
git flow feature start ajuste-timeout

# 2. Editar os arquivos necessários
# ex: nginx/conf.d/default.conf

# 3. Testar a sintaxe antes de commitar
make test

# 4. Commitar e fechar a feature (merge em develop)
git add nginx/conf.d/default.conf
git commit -m "feat: aumenta timeout do proxy para 120s"
git flow feature finish ajuste-timeout

# 5. Aplicar no servidor
make reload
```

### Publicar uma versão em produção

```bash
# 1. Criar release
git flow release start 1.1.0

# 2. Ajustes finais se necessário, depois finalizar
git flow release finish 1.1.0

# 3. Publicar master e develop com as tags
git push origin master develop --tags
```
