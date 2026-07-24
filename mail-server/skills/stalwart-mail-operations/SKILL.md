---
name: stalwart-mail-operations
description: Gerencie com segurança contas, aliases, mensagens e entrega no servidor Stalwart de filipeivopereira.com. Use para criar, alterar, listar ou excluir contas, ler mensagens autorizadas, enviar testes e diagnosticar envio ou recebimento.
---

# Stalwart Mail Operations

## Visão geral

Opere o servidor de e-mail Stalwart deste projeto com menor privilégio, rastreabilidade e respeito à privacidade. A interface administrativa é `https://mail.filipeivopereira.com/admin`, o webmail é `https://webmail.filipeivopereira.com`, e o relay padrão de saída é a Brevo.

Nunca grave, mostre, confirme ou versione senhas, tokens de API, chaves SMTP, códigos TOTP ou conteúdo de mensagens além do escopo autorizado pelo usuário.

## Antes de qualquer operação

1. Confirme a intenção, o endereço alvo e o tipo de ação. Para leitura, confirme também a caixa e o filtro de mensagens.
2. Verifique o estado atual antes de alterar algo: conta existente, alias, rota de saída ou mensagem selecionada.
3. Use uma credencial de automação com privilégio mínimo e mantenha-a somente em armazenamento protegido fora do Git. Uma chave de administração não é automaticamente uma credencial IMAP/JMAP da caixa postal.
4. Registre no retorno apenas o resultado, o identificador não sensível e o próximo passo. Nunca inclua segredos.

## Regras de autorização

| Operação | Autoridade necessária |
| --- | --- |
| Listar contas, domínios ou aliases | Pedido explícito do usuário |
| Criar ou alterar conta, alias ou senha | Pedido explícito com alvo definido |
| Excluir conta, alias ou mensagens | Confirmação explícita imediatamente antes; fazer backup quando aplicável |
| Ler e resumir e-mails | Autorização explícita, caixa e escopo definidos; minimizar conteúdo exposto |
| Enviar e-mail externo | Destinatário e conteúdo aprovados, ou autorização explícita para redigir um teste |
| Alterar DNS, firewall, relay ou implantação | Pedido explícito e validação do impacto sobre entrega/recebimento |

Não envie campanhas, mensagens de marketing ou e-mails para listas de terceiros. Para mensagens transacionais, use apenas destinatários esperados e mecanismos de opt-out quando aplicável.

## CRUD de contas e aliases

### Criar

1. Verifique se o domínio e o endereço ainda não existem.
2. Crie a conta no Stalwart com senha forte fornecida pelo usuário ou gerada e entregue por canal seguro.
3. Aplique somente as permissões necessárias e defina quota se houver política para isso.
4. Confirme a criação sem reproduzir a senha. Teste login apenas quando autorizado.

### Listar e consultar

Liste somente os campos necessários (endereço, nome, estado, quota e aliases). Não exponha hashes, credenciais, tokens, endereços de recuperação ou detalhes de segurança.

### Alterar

Leia o objeto atual, altere somente os campos solicitados e valide o resultado. Para redefinição de senha, não revele a senha em logs, documentação, terminal salvo ou commit.

### Excluir

Antes de excluir, informe impacto (login, recebimento, aliases e retenção), faça backup exportável quando houver dados, peça confirmação final e só então execute. Após isso, confirme que a conta/alias deixou de aparecer na consulta.

## Leitura de mensagens via JMAP

1. Descubra a sessão em `https://mail.filipeivopereira.com/.well-known/jmap`; use o `apiUrl` retornado em vez de assumir um endpoint fixo.
2. Autentique com credencial autorizada da própria caixa ou token explicitamente apto para JMAP.
3. Use `Email/query` para localizar mensagens por caixa, remetente, assunto, período ou estado; em seguida use `Email/get` somente para os IDs selecionados.
4. Prefira metadados e trechos. Busque `bodyValues` apenas se a leitura do corpo tiver sido autorizada.
5. Para transcrever uma resposta, reproduza o conteúdo da mensagem específica solicitada; não misture outras mensagens, assinaturas ou dados de terceiros sem necessidade.

## Envio de mensagens via JMAP

1. Confirme identidade remetente, destinatário, assunto e conteúdo.
2. Crie uma mensagem multipart: texto simples legível e versão HTML equivalente quando houver formatação. Use quebras de linha reais, nunca a sequência literal `\\n` no conteúdo.
3. Envie usando `Email/import` seguido de `EmailSubmission/set`, com a identidade remetente correta.
4. Confirme a aceitação do relay pelos logs ou pela resposta JMAP. Aceitação pelo relay não prova leitura nem chegada à caixa final.
5. Em teste de formatação, mantenha parágrafos e listas reais tanto no texto simples quanto no HTML.

## Diagnóstico de entrega

- Saída: confira se a rota padrão é `brevo`, se a Brevo está autenticada e consulte `docker service logs mail_stalwart` filtrando eventos de entrega, sem imprimir segredos.
- Recebimento: confira MX apontando para `mail.filipeivopereira.com`, PTR correspondente e conectividade SMTP na porta 25.
- Cliente: 465/TLS implícito e 993/IMAPS estão confirmados; a 587 requer teste independente de fora da VPS antes de ser anunciada como funcional externamente.
- Autenticação: preserve SPF, DKIM e DMARC sem duplicar registros ou assinaturas. A rota SES não deve se tornar padrão enquanto a Brevo for o relay ativo.

## Mudanças de infraestrutura

Antes de alterar a stack, salve a configuração atual e valide o YAML. Para implantar via Swarm, passe `MAIL_HOST` e `WEBMAIL_HOST` no ambiente do comando: `docker stack deploy` não carrega automaticamente um `.env`.

Após mudanças, valide: painel HTTPS, serviço `mail_stalwart`, criação/listagem de conta quando aplicável, envio de teste, recebimento de teste e logs.

## Conclusão e higiene de segredos

Informe o que foi feito, o que foi verificado e limitações remanescentes. Remova arquivos temporários de credenciais, revogue chaves de uso pontual e mantenha `.env` e segredos fora do repositório.

## Referência detalhada

Para checklist operacional, limites e critérios de aceite, leia [references/operations.md](references/operations.md).
