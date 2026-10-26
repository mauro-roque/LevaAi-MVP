# Guia de publicação em produção — LevaAí

Este guia descreve o que precisa ser revisado quando o LevaAí sair do endereço
temporário `workers.dev` e passar a usar o domínio oficial. Execute os itens na
ordem apresentada e **nunca** registre senhas, tokens ou chaves neste arquivo.

## 1. Antes de publicar

- Definir e registrar o domínio oficial, por exemplo `levaai.com.br`.
- Criar os subdomínios públicos:
  - `app.seudominio.com.br`: aplicação Flutter Web;
  - `api.seudominio.com.br`: API Cloudflare Worker, caso o front-end e a API
    sejam separados.
- Decidir se a aplicação e a API ficarão no mesmo domínio. O modelo mais
  simples é servir ambos pelo Worker em `app.seudominio.com.br`; assim, não há
  CORS entre front-end e API.
- Fazer backup do banco e confirmar que as migrações de `supabase/migrations/`
  foram aplicadas no projeto Supabase de produção.

## 2. Cloudflare Worker e domínio

No painel Cloudflare, associe o domínio ou uma rota ao Worker
`leva-ai-platform`. Depois atualize as variáveis de ambiente no Worker:

| Variável | Produção |
| --- | --- |
| `ALLOWED_ORIGINS` | URL final do front-end, sem barra ao final, por exemplo `https://app.seudominio.com.br` |
| `APP_ORIGIN` | Mesma URL pública do aplicativo, quando usada |
| `GOOGLE_CLIENT_ID` | Mantém o mesmo valor enquanto o cliente OAuth continuar sendo o mesmo |
| `DEMO_MODE` | `false` |
| `DEMO_VERIFICATION_CODE` | Remover a variável ou deixá-la vazia |
| `EMAIL_VERIFICATION_REQUIRED` | `true` |
| `MAIL_FROM` | Endereço do domínio verificado no Resend, por exemplo `LevaAí <noreply@seudominio.com.br>` |
| `MAPS_USER_AGENT` | Identificação real do LevaAí e e-mail de contato técnico |

Configure como **segredos** do Cloudflare, nunca no código ou no Git:

- `JWT_SECRET`: gerar um novo valor aleatório, longo e exclusivo para produção;
- `RESEND_API_KEY`: chave da conta Resend de produção;
- `MERCADO_PAGO_ACCESS_TOKEN`: somente quando os pagamentos reais forem
  ativados.

Depois de alterar variáveis ou segredos, publique uma nova versão do Worker e
valide:

```text
GET /api/health
GET /api/health/database
GET /api/config
```

O endpoint `/api/config` não deve expor segredo algum. Ele pode expor apenas o
identificador público do cliente Google.

## 3. Supabase

O Worker usa Hyperdrive para falar com PostgreSQL. Para produção:

1. Confirme que o Hyperdrive aponta para o projeto Supabase correto.
2. Aplique as migrações em ordem, incluindo
   `202610250004_google_auth.sql`.
3. Restrinja credenciais de banco ao Hyperdrive/Worker; não use senha do banco
   no Flutter Web.
4. Programe backups e revise as políticas de acesso, usuários e logs.
5. Faça um teste real de cadastro, login, criação de solicitação e aceite pelo
   prestador em uma conta de teste.

## 4. Login com Google

No Google Cloud Console, abra **Google Auth Platform → Clientes → LevaAí Web**
e atualize **Origens JavaScript autorizadas** quando o domínio mudar:

```text
https://app.seudominio.com.br
```

Remova o endereço antigo somente depois de confirmar o novo. Para permitir que
qualquer pessoa use o botão Google, abra **Público-alvo** e publique o app de
teste para produção. O login atual solicita somente identidade básica
(nome/e-mail), portanto normalmente não exige verificação adicional; ainda
assim, siga o que o Google Cloud Console indicar.

Não use a chave secreta OAuth no Flutter, no Git ou no Worker atual. O fluxo
web do LevaAí usa o identificador público e o Worker valida o token devolvido
pelo Google antes de criar a sessão.

## 5. E-mails transacionais

Para e-mails chegarem a qualquer destinatário, no Resend:

1. Adicione o domínio oficial.
2. Copie os registros DNS indicados pelo Resend para o DNS do domínio.
3. Aguarde a verificação SPF/DKIM.
4. Configure `MAIL_FROM` com um endereço desse domínio.
5. Faça testes de cadastro, recuperação de senha e notificação de nova
   solicitação para um prestador.

Enquanto `onboarding@resend.dev` estiver configurado, o Resend limita o envio
aos endereços permitidos pela conta de teste.

## 6. Pagamentos

Antes de receber pagamentos reais:

- Troque credenciais de sandbox pelas credenciais de produção do Mercado Pago;
- Confirme URLs de retorno e webhooks no domínio final;
- Valide assinatura dos webhooks no Worker;
- Faça uma transação de baixo valor e o fluxo de estorno;
- Estabeleça processo de suporte para pagamento recusado, cancelamento e
reembolso.

Não habilite cobrança real sem testar o ciclo completo em sandbox.

## 7. Mapas, CEP e rotas

O projeto usa consulta de CEP/geocodificação e rota. Em produção, confira os
limites e termos dos provedores. Caso o volume aumente, contrate ou hospede um
provedor compatível e atualize as variáveis `NOMINATIM_URL` e `OSRM_URL` no
Worker. Não use serviços públicos acima dos limites permitidos.

## 8. Segurança e operação

- Rotacione imediatamente qualquer token, senha de banco, chave de e-mail ou
  chave OAuth que tenha sido exibida em conversa, captura de tela ou log.
- Revise os logs do Cloudflare e Supabase sem gravar tokens ou senhas.
- Mantenha HTTPS obrigatório e HSTS ativo.
- Configure monitoramento para `/api/health/database` e alertas de erro 5xx.
- Faça revisão de dependências e testes antes de cada publicação.
- Use uma branch de homologação antes de alterar a branch `platform`.
- Defina política de privacidade, termos de uso e canal de suporte antes da
  divulgação pública.

## Checklist de liberação

- [ ] Domínio e HTTPS funcionam.
- [ ] Worker aponta para o banco Supabase de produção.
- [ ] Migrações aplicadas e backup confirmado.
- [ ] CORS/`ALLOWED_ORIGINS` contém apenas o domínio oficial.
- [ ] Login por e-mail, recuperação de senha e confirmação por e-mail testados.
- [ ] Login Google testado no domínio oficial e publicado para usuários finais.
- [ ] E-mail Resend usa domínio verificado.
- [ ] Pagamento real continua desligado ou foi validado em sandbox e produção.
- [ ] Fluxo cliente → solicitação → prestador → aceite foi testado.
- [ ] Segredos rotacionados e fora do Git.
- [ ] Monitoramento e plano de suporte definidos.
