# Preparação para produção

Esta cópia evolui separadamente do MVP em `LevaAi-MVP`.

Ao publicar com `wrangler.production.jsonc.example`, o modo demonstração fica desligado: não são criadas contas de exemplo, o formulário pesquisa endereços reais e a rota é calculada pelo provedor de mapas. Usuários e prestadores passam a ser exclusivamente os que se cadastrarem no aplicativo.

## O que já foi preparado

- Cadastro passa a exigir confirmação por e-mail antes de liberar o login.
- Códigos são aleatórios, expiram em 24 horas e só o hash é persistido.
- A senha e as chaves do provedor nunca ficam no repositório.
- A migração `202610160003_email_verification.sql` cria a estrutura necessária.

## Ativação do envio real

1. Crie uma conta Resend e verifique um domínio próprio, como `levaai.com.br`.
2. No Cloudflare Worker, configure os segredos `RESEND_API_KEY` e `MAIL_FROM`.
3. Configure `EMAIL_VERIFICATION_REQUIRED=true` e `APP_ORIGIN` com o domínio final.
4. Configure `ALLOWED_ORIGINS` com os domínios públicos separados por vírgula. O Worker rejeita chamadas CORS de outras origens.
5. Aplique as migrações SQL em ordem no Supabase.

O domínio e a conta do provedor pertencem ao proprietário do produto; por isso esta etapa não é automatizada no código.

## Operação em escala

- Use um Worker, um banco e um Hyperdrive exclusivos para produção; o ambiente MVP continua isolado.
- Configure uma regra **Rate limiting** no painel Cloudflare para `/api/auth/*` e `/api/*`, pois o limite em memória do Worker é apenas uma proteção complementar por instância.
- Mantenha `DEMO_MODE=false` em produção e monitore os endpoints `/api/health` e `/api/health/database`.
- Proteja `main` no GitHub: pull request obrigatório, aprovação de revisão e execução do workflow antes do merge.
