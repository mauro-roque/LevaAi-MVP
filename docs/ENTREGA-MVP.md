# LevaAí — MVP atualizado

## Executar agora

Na pasta `LevaAi-MVP`, execute `./Iniciar-MVP.ps1 -Recompilar` e abra http://127.0.0.1:3000.
O script usa Flutter Web e a mesma API de negócio do Worker. Localmente, PostgreSQL roda através do PGlite e os dados ficam em `cloudflare-worker/.local-data`, ignorados pelo Git. Não precisa instalar um servidor PostgreSQL para a apresentação. Ao reiniciar esse servidor local, as sessões anteriores deixam de ser válidas; os cadastros e pedidos permanecem salvos.

O servidor antigo em `backend/` e sua base SQLite são legados. A entrada atual é `cloudflare-worker/scripts/local-server.mjs`; o código de produção está em `cloudflare-worker/src/index.mjs` e `normalized-api.mjs`.

## Fluxo principal

1. As três telas de apresentação aparecem apenas no primeiro acesso naquele navegador. É possível pular.
2. O visitante informa origem, destino, data, itens, peso, volume e ajudantes; pode pesquisar sem conta.
3. A API filtra prestadores por disponibilidade, raio, capacidade, equipe e reserva do veículo por dia. O preço é calculado no servidor.
4. Ao escolher um prestador, o app pede login ou cadastro de cliente. A busca e a escolha são preservadas. A API recalcula a cotação após entrar e exige nova escolha se o preço mudar.
5. O pedido aguarda o aceite. O prestador aceita ou recusa. Somente depois do aceite o cliente pode gerar o Pix.
6. A confirmação do Pix agenda o serviço. O prestador avança: a caminho → em andamento → concluído.
7. O cliente avalia uma única vez após a conclusão. A média é atualizada na tabela `prestadores`.

Também inclui edição de nome/telefone, endereços favoritos, disponibilidade, veículos e ajudantes, detalhes públicos e avaliações do prestador, histórico de status, confirmação de cancelamento e retomada de sessão na mesma aba.

## Demonstração

Em banco vazio com `DEMO_MODE=true`, a API cria três contas e três veículos. Nunca use esse modo para operação real.

| Perfil | E-mail | Senha |
| --- | --- | --- |
| Cliente | cliente@levaai.demo | LevaAi@123 |
| Prestador | prestador@levaai.demo | LevaAi@123 |
| Outro prestador | horizonte@levaai.demo | LevaAi@123 |

Use “Preencher um frete de exemplo” para um percurso simulado, explicitamente identificado. Depois de solicitar, entre como prestador em outra aba, aceite, volte ao cliente e simule o Pix. Nenhuma cobrança real é criada. Em banco que já contém usuários, o seed não adiciona contas automaticamente.

## Banco Supabase existente

A API nova utiliza `public.usuarios`, `clientes`, `prestadores`, `veiculos`, `ajudantes`, `enderecos`, `solicitacoes`, `itens_mudanca`, `orcamentos`, `servicos`, `pagamentos`, `avaliacoes` e `historico_status` do modelo enviado pelo usuário.

Execute, nesta ordem, no projeto correto:

1. `supabase/migrations/202609200001_base_original.sql`: cria a base quando necessário, sem comandos DROP e sem remover dados. Pode ser reaplicada.
2. `supabase/migrations/202609200002_mvp.sql`: adiciona os campos de integração e tabelas auxiliares no schema privado `leva_ai_private` para sessões, cotações temporárias, reservas, recuperação e favoritos.

Não execute o `SCRIPT.txt` original em um banco com dados: ele contém comandos DROP. A antiga migração `cloudflare-worker/migrations/001_leva_ai_mvp_postgres.sql` pertence à versão anterior; não é a migração da API atual. Dados de `leva_ai_mvp.users/bookings` não são importados automaticamente para o modelo original.

A migração ativa RLS e revoga acesso das funções `anon` e `authenticated` às tabelas de negócio; o aplicativo acessa os dados exclusivamente pelo Worker. Se outro aplicativo já usa essas tabelas diretamente, revise essa integração antes de aplicar. As funções/tabelas originais são preservadas, com índices adicionais para evitar reservas duplicadas.

Contas originais precisam ter hash PBKDF2 no formato do aplicativo. Senhas de outro sistema não são convertidas automaticamente; use recuperação após configurar e-mail. Pedidos históricos sem os snapshots de cotação da aplicação exigem importação específica antes de aparecerem na interface nova.

## Publicar no Cloudflare Workers

O projeto já contém o Worker `leva-ai-mvp`, um vínculo Hyperdrive e a configuração para servir os arquivos estáticos do Flutter. Confira se o vínculo aponta para o projeto Supabase desejado antes de aplicar as migrações e publicar.

1. Aplique as duas migrações no Supabase e confirme o schema.
2. Use o vínculo `HYPERDRIVE` com cache de consultas desativado: reservas, pagamentos e sessões precisam refletir escritas recentes. Pelo Wrangler: `wrangler hyperdrive update ID_DO_VINCULO --caching-disabled`.
3. Configure `JWT_SECRET` como segredo com pelo menos 32 caracteres aleatórios. `DEMO_MODE=true` é para apresentação; use `false` para modo real.
4. Em `cloudflare-worker`, execute `npm ci`, `npm run build`, `npx wrangler deploy --dry-run` e `npx wrangler deploy`.
5. Confira `/api/health`, `/api/health/database` e o fluxo de cadastro → pesquisa → pedido no endereço publicado.

Não publique a nova API antes de aplicar as migrações. Chaves e credenciais ficam nos segredos do Worker; nunca no Flutter. A aplicação web e a API usam o mesmo domínio. Conexões locais de desenvolvimento são aceitas em localhost.

Referências oficiais: [Hyperdrive e consistência das consultas](https://developers.cloudflare.com/hyperdrive/concepts/query-caching/) e [acesso PostgreSQL no Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres).

## Integrações opcionais

- **Recuperação por e-mail:** configure `RESEND_API_KEY` e `MAIL_FROM` com um remetente verificado. O código é válido por 30 minutos, armazenado como hash, de uso único; redefinir a senha revoga as sessões. Sem o provedor, a interface informa a indisponibilidade. O envio externo não foi homologado nesta entrega.
- **Pix real:** configure `MERCADO_PAGO_ACCESS_TOKEN` e `DEMO_MODE=false`. O cliente usa “Consultar pagamento”; a API verifica valor, referência, moeda e método. Não há confirmação pelo navegador. O adaptador precisa de homologação na conta de pagamentos antes de uso real.
- **Mapas:** Nominatim, OSRM e OpenStreetMap estão separados no adaptador de mapas. Configure `NOMINATIM_URL`, `OSRM_URL` e `MAPS_USER_AGENT` para seus provedores. Os serviços públicos têm limites; a limitação local não coordena múltiplas instâncias do Worker. Para tráfego público, use provedores adequados à carga prevista. OSRM usa rota de automóvel, sem restrições de caminhão.

## Limites do MVP

Reserva por veículo/dia, sem agenda por horário ou expiração automática. Equipe de ajudantes declarada por veículo. Peso/volume são estimativas; itens são descrição textual (separe por ponto e vírgula ou linha), sem cálculo automático de volume. Comparação por cards, sem tela dedicada. Os status atualizam pelo botão de atualização, sem GPS em tempo real.

Cancelamento pelo cliente é permitido antes da emissão do Pix. Depois disso, é necessário atendimento/conciliação; reembolso automático, cartão, split, notificações push, chat e cupons não estão implementados. As avaliações são restritas a serviços concluídos. Recuperação de senha por e-mail requer provedor configurado.

## Verificação

- `cd cloudflare-worker; npm test`: autenticação e fluxo completo no PostgreSQL/PGlite, incluindo migração reaplicável, acesso por dono, capacidade, reserva, idempotência, estados, Pix demonstrativo, avaliação, perfil e veículos.
- `cd frontEnd/leva_ai; flutter analyze; flutter test; flutter build web --release`: análise, apresentação e acesso visitante, erro de login e layouts em 390 e 1440 pixels.
- Verificação manual local: busca visitante → seleção → login → pedido salvo com a rota e o preço preservados.

Publicação e validação remota precisam ser confirmadas no projeto Supabase conectado. O guia não afirma que a migração remota já foi aplicada.
