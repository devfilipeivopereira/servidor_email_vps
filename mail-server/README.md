# Servidor de e-mail — filipeivopereira.com

Documentação operacional do servidor Stalwart hospedado na VPS atual. O projeto mantém a configuração de implantação, mas **nunca** credenciais, senhas, chaves SMTP ou tokens de API.

## Estado atual

O serviço está ativo e usa a infraestrutura já existente da VPS:

| Componente | Situação |
| --- | --- |
| Administração Stalwart | `https://mail.filipeivopereira.com/admin` |
| Área da conta Stalwart | `https://mail.filipeivopereira.com/account` |
| Webmail | `https://webmail.filipeivopereira.com` |
| Domínio de e-mail | `filipeivopereira.com` |
| Relay de saída | Brevo, via SMTP autenticado e STARTTLS na porta 587 |
| Entrada de e-mails | MX aponta para `mail.filipeivopereira.com` |
| PTR do IPv4 da VPS | `mail.filipeivopereira.com` |
| Autenticação do administrador | senha própria + TOTP |

O Stalwart e o SnappyMail rodam no Docker Swarm e compartilham a rede externa `FilipeNet` com o Traefik existente. Os volumes persistentes são próprios do stack `mail` e não pertencem aos demais serviços da VPS.

## Arquitetura

```text
Internet
  ├─ HTTPS 443 ── Traefik ── Stalwart (/admin, /account, JMAP)
  │                         └─ SnappyMail (webmail)
  ├─ SMTP 25 ────────────── Stalwart ── caixas locais
  ├─ SMTPS 465 / SMTP 587 ─ Stalwart ── autenticação de usuários
  └─ IMAPS 993 ──────────── Stalwart ── caixas locais

Stalwart ── STARTTLS 587 ── smtp-relay.brevo.com ── destinatários externos
```

O relay `brevo` é a rota padrão para e-mails externos. A rota antiga `amazon-ses` foi mantida no Stalwart apenas como referência e não é a rota padrão.

## DNS

Os registros abaixo devem ser preservados. Use TTL 300 enquanto estiver alterando a infraestrutura; depois pode ser aumentado.

| Tipo | Nome | Valor / destino | Finalidade |
| --- | --- | --- | --- |
| A | `mail` | IPv4 da VPS | Stalwart e SMTP/IMAP |
| A | `webmail` | IPv4 da VPS | SnappyMail |
| MX | `@` (prioridade 10) | `mail.filipeivopereira.com` | Recebimento de e-mails |
| CNAME | `send` | `send-filipeivopereira-com.brand.brevosend.com` | Marca de links Brevo |
| TXT | `@` | código de verificação Brevo | Validação de domínio Brevo |
| CNAME | `brevo1._domainkey` | DKIM Brevo fornecido no painel | Assinatura Brevo |
| CNAME | `brevo2._domainkey` | DKIM Brevo fornecido no painel | Assinatura Brevo |
| CNAME | `img.send` | redirecionamento de imagens Brevo | Rastreamento de imagens |
| CNAME | `r.send` | redirecionamento de links Brevo | Rastreamento de links |

Também existem três CNAMEs DKIM da Amazon SES. Eles podem continuar publicados: os seletores são diferentes dos da Brevo e não conflitam.

### DMARC e SPF

- Deve existir **apenas um** TXT em `_dmarc`. Nunca crie um segundo registro DMARC.
- Ao criar ou alterar SPF, mantenha todos os provedores autorizados no mesmo registro TXT. Não crie dois registros SPF.
- Para o início da operação, use uma política DMARC de monitoramento (`p=none`) e evolua para `quarantine` ou `reject` somente após acompanhar os relatórios.

## Portas e firewall

O UFW da VPS permite TCP 25, 465, 587 e 993, além das portas já usadas pelos demais serviços.

| Porta | Serviço | Uso |
| ---: | --- | --- |
| 25 | SMTP | Recebimento entre servidores |
| 465 | SMTPS | Envio autenticado com TLS implícito |
| 587 | Submission | Envio autenticado com STARTTLS |
| 993 | IMAPS | Leitura de e-mails com TLS |

Os listeners internos do Stalwart estão ativos nas quatro portas. A conectividade de 25, 465 e 993 foi confirmada; a 587 deve ser testada novamente a partir de uma rede externa independente antes de ser adotada como configuração padrão de cliente. Enquanto isso, use 465 com TLS implícito.

Não publique portas administrativas adicionais. O painel usa HTTPS por meio do Traefik.

## Webmail SnappyMail

O SnappyMail é um cliente de e-mail separado do Stalwart. Como ambos rodam em contêineres distintos, **não** configure IMAP ou SMTP como `localhost`: isso faria o webmail tentar alcançar a si próprio e causa o erro `tcp://localhost:143`.

A configuração operacional validada no volume do SnappyMail é:

| Função | Host interno | Porta | Segurança | Autenticação |
| --- | --- | ---: | --- | --- |
| IMAP | `mail_stalwart` | 993 | TLS implícito | e-mail completo e senha da caixa |
| SMTP | `mail_stalwart` | 465 | TLS implícito | e-mail completo e senha da caixa |

Os dois perfis de domínio do SnappyMail (padrão e específico) devem usar esses valores, com SMTP autenticado. Após qualquer mudança, reinicie somente `mail_snappymail`, confirme que o serviço convergiu e valide a URL `https://webmail.filipeivopereira.com` antes de testar o login.

Não use 143 ou 587 para a comunicação interna do SnappyMail sem uma validação específica: nesta implantação os canais internos confirmados são 993 e 465. Para clientes externos, permanecem válidos os mesmos parâmetros públicos: 993/IMAPS e 465/SMTPS.

## Brevo: saída de e-mails

A conta Brevo está com o domínio autenticado. A configuração no Stalwart usa:

```text
Host: smtp-relay.brevo.com
Porta: 587
Segurança: STARTTLS obrigatório
Autenticação: login SMTP + chave SMTP da Brevo
Rota Stalwart: brevo
```

As credenciais ficam somente em arquivo restrito na VPS e na configuração secreta do Stalwart. Elas não devem ser adicionadas a `.env` versionado, ao repositório, a screenshots ou a mensagens de e-mail.

Para trocar a chave SMTP:

1. Gere uma nova chave em **Brevo → Configurações → SMTP & API**.
2. Atualize a rota `brevo` no Stalwart.
3. Faça um envio de teste para uma caixa externa.
4. Revogue a chave antiga na Brevo depois da confirmação.

## Administração e contas

Uma conta inicial foi criada:

```text
livro_01@filipeivopereira.com
```

Para criar ou administrar contas pela interface, use o painel Stalwart. Para automação por SSH, o wrapper `mailctl` deste repositório oferece:

```text
mailctl list
mailctl create localpart "Nome" [quota-em-bytes] [senha]
mailctl password endereco nova-senha
mailctl alias-add endereco alias-localpart [descricao]
mailctl alias-remove endereco alias-localpart
mailctl delete endereco --confirm endereco
```

Instale-o com `scripts/install-mailctl.sh`. O arquivo `/etc/mailops/mailctl.env` deve ser `root:root`, modo `0600`, e conter uma credencial Stalwart dedicada com privilégios mínimos. A exclusão exige um comando de backup configurado e só é executada após esse backup terminar com sucesso.

Use uma chave de API temporária para mudanças pontuais de infraestrutura e revogue-a ao terminar. Para o CRUD contínuo, crie uma credencial separada e limitada aos privilégios de contas; não reutilize a chave administrativa completa.

## Arquivos de implantação

| Arquivo | Uso |
| --- | --- |
| `stack.current-vps.web.yaml` | Modo web seguro: somente HTTPS via Traefik, sem portas SMTP/IMAP públicas |
| `stack.current-vps.production.yaml` | Modo operacional: publica 25, 465, 587 e 993 em modo `host` |
| `stack.current-vps.bootstrap.yaml` | Inicialização isolada para uma nova instalação |
| `compose.yaml` | Referência para VPS dedicada, não para a VPS compartilhada atual |
| `scripts/preflight.sh` | Valida DNS, PTR, portas, rota de saída e UFW antes da ativação |

Para aplicar o modo operacional na VPS atual:

```bash
cd /opt/mailserver
MAIL_HOST=mail.filipeivopereira.com \
WEBMAIL_HOST=webmail.filipeivopereira.com \
docker stack deploy -c stack.current-vps.production.yaml mail
```

> `docker stack deploy` não lê automaticamente um arquivo `.env`. Por isso os nomes dos hosts devem ser exportados ou passados no mesmo comando.

## Testes já realizados

1. DNS de `mail` e `webmail` confirmado apontando para a VPS.
2. PTR confirmado para `mail.filipeivopereira.com`.
3. Domínio validado e DKIM habilitado na Amazon SES.
4. Domínio validado e autenticação de marca concluída na Brevo.
5. Autenticação SMTP da Brevo validada pela própria VPS.
6. E-mail externo enviado por `livro_01@filipeivopereira.com` e aceito pela Brevo com resposta SMTP `250`.
7. Resposta de um endereço Hotmail recebida com sucesso na caixa `livro_01` após a ativação do MX.
8. Envio em HTML e texto simples validado para evitar quebras de linha literais (`\\n`).
9. Webmail corrigido: os perfis SnappyMail agora usam `mail_stalwart` com IMAPS 993 e SMTPS 465; a página HTTPS retornou `200` após o reinício.

## Operação segura

- Mantenha 2FA no administrador Stalwart.
- Não armazene senhas, chaves SMTP, tokens AWS ou tokens Stalwart no Git.
- Antes de alterações de DNS, exporte a zona atual.
- Antes de excluir uma conta, faça backup e exija confirmação explícita.
- Verifique logs de entrega após cada mudança de relay: `docker service logs mail_stalwart`.
- Faça atualizações de imagem de forma planejada e teste administração, envio e recebimento após cada atualização.
- Monitore bounces e reclamações no painel da Brevo. Não use listas compradas, raspadas ou sem consentimento.

## Skill operacional do projeto

O projeto inclui a skill [Stalwart Mail Operations](skills/stalwart-mail-operations/SKILL.md), que padroniza o CRUD de contas e aliases, leitura autorizada, envio multipart (texto e HTML), diagnóstico de entrega e controles de segurança. Ela não contém credenciais e exige autorização explícita para ler, enviar ou excluir e-mails.

## Solução de problemas

| Sintoma | Verificação |
| --- | --- |
| E-mail não chega ao domínio | `dig MX filipeivopereira.com` deve retornar `mail.filipeivopereira.com` e TCP 25 deve estar liberado |
| E-mail externo não sai | Verifique a rota `brevo`, a chave SMTP e os logs de `delivery.*` do Stalwart |
| Rejeição por DKIM duplicado | Confirme que a rota padrão é `brevo`; não use a rota SES simultaneamente |
| Cliente não conecta na 587 | Teste de outra rede; use 465/TLS implícito enquanto a 587 não estiver confirmada externamente |
| Webmail informa `tcp://localhost:143` | Ajuste os perfis SnappyMail para `mail_stalwart:993` (IMAP/TLS) e `mail_stalwart:465` (SMTP/TLS com autenticação) |
| Painel não abre | Confirme o serviço `mail_stalwart`, o Traefik e o certificado HTTPS |
