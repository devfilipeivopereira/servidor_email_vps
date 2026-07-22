# Implantação do servidor de e-mail

Este diretório prepara uma VPS dedicada para `filipeivopereira.com`. Ele não deve ser executado na VPS atual, que já mantém serviços de produção.

## VPS atual (modo seguro)

Para a VPS atual, use os arquivos `stack.current-vps.bootstrap.yaml` e `stack.current-vps.production.yaml`, não o `compose.yaml`. A primeira fase não publica nenhuma porta nem rota web; ela apenas baixa e inicializa os serviços numa rede interna. A segunda reutiliza o Traefik existente e só pode ser aplicada depois de o DNS, o PTR e o relay SMTP terem sido validados. Os volumes persistentes têm nomes próprios e não interferem nos serviços atuais.

## Pré-requisitos externos

1. VPS Ubuntu 24.04 LTS com IPv4 dedicado, 4 vCPU, 8 GB RAM e 400 GB NVMe.
2. O provedor deve permitir entrada e saída na porta 25 e alterar o PTR para `mail.filipeivopereira.com`.
3. Token Hostinger com acesso à zona DNS e conta Amazon SES na região `sa-east-1`.
4. DNS inicial: `mail` e `webmail` apontam para a nova VPS antes da primeira emissão de certificado.

## Bootstrap

1. Copie `.env.example` para `.env` e ajuste somente nomes e versões.
2. Copie `secrets/stalwart-bootstrap.env.example` para `secrets/stalwart-bootstrap.env`, gere uma senha aleatória e limite as permissões a `0600`.
3. Instale Docker Engine e o plugin Compose na VPS; crie o diretório `/opt/mailserver` e copie este conteúdo para lá.
4. Libere no firewall TCP `25`, `465`, `587` e `993`; execute `./scripts/preflight.sh mail.filipeivopereira.com webmail.filipeivopereira.com`. Corrija todo erro obrigatório antes de prosseguir.
5. Rode `docker compose config` e depois `docker compose up -d`.
6. Conclua o assistente Stalwart em `https://mail.filipeivopereira.com/admin`: diretório interno, domínio principal, DNS Hostinger, ACME DNS-01, DKIM e relay SES.
7. Crie o administrador permanente, habilite 2FA, remova `STALWART_RECOVERY_ADMIN` e recrie somente o serviço Stalwart.
8. Configure SnappyMail para IMAPS `mail.filipeivopereira.com:993` e SMTP STARTTLS `mail.filipeivopereira.com:587`; bloqueie o painel administrativo próprio do SnappyMail no proxy.

## Operação por SSH

Após o bootstrap, instale `mailctl` em `/usr/local/sbin/mailctl`, crie `/etc/mailops/mailctl.env` com acesso mínimo e dê permissão somente ao usuário `mailops`. A conta de automação deve ter permissões apenas de CRUD de contas. O arquivo precisa conter `MAILCTL_URL=https://mail.filipeivopereira.com`, `MAILCTL_USER`, `MAILCTL_PASSWORD`, `MAILCTL_DOMAIN_ID`, `MAILCTL_DOMAIN=filipeivopereira.com` e `MAILCTL_BACKUP_COMMAND`. A exclusão só é executada depois de o comando de backup definido por essa última variável terminar com sucesso.

O instalador `./scripts/install-mailctl.sh` instala o comando e cria o arquivo de configuração vazio, sem gravar senhas. O CRUD disponível é: listar caixas, criar, trocar senha, criar/remover aliases e excluir com confirmação explícita e backup prévio.

Antes do corte de MX: faça cópia IMAP da caixa existente na Hostinger, crie credenciais de aplicativo separadas para Directus e n8n, e atualize-os para usar a submissão Stalwart.
