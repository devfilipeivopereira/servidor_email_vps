# Checklist operacional do Stalwart

## Contexto da implantação

- Domínio: `filipeivopereira.com`.
- Administração: `https://mail.filipeivopereira.com/admin`.
- JMAP: descubra sempre por `https://mail.filipeivopereira.com/.well-known/jmap`.
- Webmail: `https://webmail.filipeivopereira.com`.
- Relay de saída ativo: Brevo, por STARTTLS na porta 587.
- Portas confirmadas para clientes: 465 (TLS implícito) e 993 (IMAPS). Não prometa disponibilidade pública da 587 sem teste de uma rede externa independente.
- SnappyMail interno: IMAP em `mail_stalwart:993` e SMTP autenticado em `mail_stalwart:465`, ambos com TLS implícito. Não usar `localhost`, 143 ou 587 sem nova validação.

## Critérios de aceite

| Ação | Evidência mínima |
| --- | --- |
| Criar conta | Conta aparece na consulta e, se autorizado, login válido |
| Alterar conta | Campos alterados conferem sem expor credenciais |
| Excluir conta | Confirmação final, backup quando aplicável e conta ausente da consulta |
| Enviar mensagem | Operação JMAP aceita e relay registra aceitação |
| Receber mensagem | Mensagem localizada na caixa autorizada via JMAP |
| Formatação | Texto simples tem parágrafos reais e HTML equivalente |
| Webmail | Serviço `mail_snappymail` convergiu e URL HTTPS responde 200 após a alteração |

## Boas práticas de conteúdo

- Assunto objetivo e remetente verificado.
- Texto simples como alternativa acessível ao HTML.
- Sem cabeçalhos DKIM adicionados manualmente: deixe o relay assinar.
- Não confundir aceitação SMTP/JMAP com entrega final; bounce, reclamação ou bloqueio podem ocorrer depois.
- Trate endereços, conteúdo de e-mail e identificadores de mensagens como dados privados.

## Diagnóstico seguro

1. Consulte o estado do serviço antes de reiniciar ou redistribuir uma stack.
2. Revise logs por ID de mensagem, domínio de destino e status de entrega; remova linhas com credenciais antes de compartilhar.
3. Para falha de saída, confirme rota Brevo, conexão segura e identidade remetente autenticada.
4. Para falha de entrada, valide MX, porta 25 e registros de recebimento.
5. Para falha de cliente, confirme host, porta, segurança TLS e credenciais da própria caixa.
6. Para erro `tcp://localhost:143`, corrija ambos os perfis de domínio do SnappyMail; preserve backup antes da edição e reinicie apenas o serviço do webmail.

## Operações que exigem cautela adicional

- Exclusão de contas ou mensagens.
- Alteração de DNS, SPF, DKIM, DMARC, PTR ou MX.
- Mudança de relay, firewall, portas publicadas ou versão do Stalwart.
- Rotação de chaves Brevo/Stalwart e qualquer credencial usada por automação.
