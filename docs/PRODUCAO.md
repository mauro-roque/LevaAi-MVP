# Preparação para produção

Esta cópia evolui separadamente do MVP em `LevaAi-MVP`.

## O que já foi preparado

- Cadastro passa a exigir confirmação por e-mail antes de liberar o login.
- Códigos são aleatórios, expiram em 24 horas e só o hash é persistido.
- A senha e as chaves do provedor nunca ficam no repositório.
- A migração `202610160003_email_verification.sql` cria a estrutura necessária.

## Ativação do envio real

1. Crie uma conta Resend e verifique um domínio próprio, como `levaai.com.br`.
2. No Cloudflare Worker, configure os segredos `RESEND_API_KEY` e `MAIL_FROM`.
3. Configure `EMAIL_VERIFICATION_REQUIRED=true` e `APP_ORIGIN` com o domínio final.
4. Aplique as migrações SQL em ordem no Supabase.

O domínio e a conta do provedor pertencem ao proprietário do produto; por isso esta etapa não é automatizada no código.
