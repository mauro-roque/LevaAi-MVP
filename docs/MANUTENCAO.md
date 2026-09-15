# Manutenção do LevaAí MVP

## Onde cada responsabilidade está

- `frontEnd/leva_ai/lib/mvp`: fluxo Flutter usado pelo aplicativo publicado.
- `cloudflare-worker/src`: API publicada no Cloudflare Worker. É a referência para produção.
- `cloudflare-worker/migrations`: alterações de banco executadas no Supabase, no schema `leva_ai_mvp`.
- `backend/src`: servidor Node local para desenvolvimento e comparação das regras da API.

O Flutter chama `/api` na mesma origem quando está publicado na web. Por isso, o Worker entrega a interface e a API no mesmo endereço. O Worker só acessa o Supabase por meio do binding Hyperdrive; chaves e strings de conexão nunca devem ser incluídas no Flutter, no Git ou em arquivos de configuração versionados.

## Antes de alterar uma funcionalidade

1. Localize a rota correspondente no Worker e a tela correspondente em `lib/mvp`.
2. Se houver mudança de dados, crie uma nova migration numerada. Não altere uma migration que já foi executada.
3. Mantenha a mesma regra no backend local se ele for usado para demonstração fora do Cloudflare.
4. Teste o caso normal, uma falha de validação e uma chamada sem autenticação quando a rota for protegida.

## Formatação e validação

No Flutter, execute `dart format lib test`, depois `flutter analyze` e `flutter test` dentro de `frontEnd/leva_ai`.

No Worker e no backend local, execute `npm run format:check` e `npm test` dentro de cada pasta. Use `npm run format` para corrigir a indentação automaticamente.

## Integração publicada

As configurações privadas ficam no painel da Cloudflare. O Worker exige `JWT_SECRET` e, para acessar dados reais, o binding `HYPERDRIVE` apontando para o projeto Supabase. Quando essa ligação for criada ou alterada, teste `GET /api/health` e o acesso pelo navegador antes de publicar novas telas.
