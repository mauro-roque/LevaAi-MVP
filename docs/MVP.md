# LevaAí — MVP

Implementação local em Flutter Web + Node.js, no repositório original. O fluxo principal está conectado à API; as telas antigas de catálogo permanecem no repositório, mas não são o ponto de entrada.

## Executar

Requisitos: Node.js 22.13+ e Flutter 3.29.3 / Dart 3.7.2 ou versões compatíveis. Na raiz `Leva-Ai`:

```powershell
.\Iniciar-MVP.ps1
```

Abra http://127.0.0.1:3000. Na primeira execução, o script compila a interface. Para recompilar após mudanças: `./Iniciar-MVP.ps1 -Recompilar`. Não é necessário instalar PostgreSQL para demonstrar: o SQLite persiste os dados em `backend/data/leva-ai.sqlite`. Encerre o servidor com Ctrl+C.

Se a política do PowerShell impedir a execução, não precisa alterá-la: execute `flutter pub get` e `flutter build web --release` na pasta `frontEnd/leva_ai`; depois execute `node --env-file-if-exists=.env src/server.mjs` em `backend`.

## Publicar gratuitamente: Render + Supabase

O repositório inclui `Dockerfile` e `render.yaml` para publicar a interface e a API juntas no Render. O banco deve ser o PostgreSQL do Supabase: não use SQLite hospedado, pois o plano gratuito do Render perde arquivos locais quando o serviço reinicia ou fica inativo.

1. Envie as alterações deste repositório para o GitHub.
2. No [Render](https://render.com), crie uma conta, escolha **New → Blueprint** e conecte o repositório `GabrielG777/Leva-Ai`. O arquivo `render.yaml` cria o serviço gratuito.
3. No Supabase, abra o projeto, vá em **Connect** e copie a URL de conexão PostgreSQL pelo pooler em modo **Session**. No Render, preencha a variável secreta `DATABASE_URL` com ela. Não cole essa URL em arquivos do repositório nem no Flutter.
4. Confirme o deploy e aguarde o endereço `https://…onrender.com`. A primeira inicialização cria o schema `leva_ai_mvp`, sem apagar as tabelas existentes no schema público.

O serviço é publicado com `DEMO_MODE=true`: há contas de demonstração e o Pix continua simulado. O Render gratuito pode suspender a aplicação depois de inatividade; a primeira visita posterior pode levar cerca de um minuto. O Supabase gratuito também pode pausar projetos pouco utilizados após uma semana. Essa combinação é adequada para apresentação do TCC, não para operação comercial.

## Roteiro de demonstração

1. Na tela de entrada, clique em **Testar cliente**.
2. Clique em **Preencher um frete de exemplo**, depois **Encontrar prestadores**.
3. Solicite um veículo de **Carlos Transportes**. Os valores são calculados no servidor.
4. Abra uma segunda aba e clique em **Testar prestador**. Aceite o pedido.
5. Na aba do cliente, atualize as solicitações, gere o Pix e clique em **Simular pagamento aprovado**.
6. No prestador, atualize e avance: **Estou a caminho → Iniciar transporte → Concluir serviço**.
7. No cliente, atualize e avalie o serviço. Consulte a rota e a linha do tempo no histórico.
8. No prestador, visite **Meus veículos** para cadastrar/editar preço por km, capacidade, ajudantes e base de atendimento; em **Meu perfil**, altere a disponibilidade.

Contas exclusivas de demonstração, senha `LevaAi@123`:

| Perfil | E-mail |
|---|---|
| Cliente | cliente@levaai.demo |
| Carlos Transportes | prestador@levaai.demo |
| Mudanças Horizonte | horizonte@levaai.demo |

Também é possível cadastrar clientes e prestadores pela interface. A sessão fica em memória no navegador: ao recarregar a página é preciso entrar novamente. Pedidos e cadastros permanecem no banco. Não há recuperação de senha nesta etapa.

## O que está implementado

- Cadastro e login por perfil, senha com scrypt, JWT HS256 de oito horas e revogação no logout.
- Cadastro/edição de veículos, capacidade em kg e m³, preço/km, equipe de ajudantes por veículo, preço por ajudante, endereço base, raio e disponibilidade.
- Solicitação com endereços, data, itens/quantidades em texto, peso, volume e ajudantes.
- Busca explícita de endereços no Nominatim, rota de carro no OSRM e mapa OpenStreetMap; sem autocomplete a cada tecla.
- Comparação ordenada por preço com avaliação, distância aproximada do prestador até a origem e capacidade.
- Orçamentos com validade de 15 minutos, preços em centavos e revalidação na reserva.
- Reserva idempotente, aceite/recusa, bloqueio de dupla reserva por veículo/data, Pix e acompanhamento.
- Histórico de mudanças de status, avaliação única após conclusão e média calculada com avaliações reais do banco.
- Painel do prestador com serviços em aberto e total de serviços concluídos.
- SQLite local e adaptador PostgreSQL com migração aditiva em schema isolado.
- Autorização por dono/perfil, consultas parametrizadas, limites de corpo/requisições, CORS com lista permitida, respostas sem hash de senha e identificadores para erros.

## Mapas e rota de exemplo

O exemplo usa três pontos públicos de São Paulo e uma distância simulada explicitamente identificada. Não desenha uma linha reta como se fosse uma rota rodoviária. Desative **Usar rota simulada** para calcular uma rota real, ou pesquise e selecione os endereços completos. Se o provedor falhar, a interface informa o erro; não substitui a rota por uma estimativa silenciosa.

O Nominatim tem cache de até 500 buscas e intervalo mínimo de 1,1 segundo entre consultas por processo. Os provedores são configuráveis por `NOMINATIM_URL`, `OSRM_URL` e `MAPS_USER_AGENT`. Para operação comercial, use serviço contratado ou infraestrutura própria com capacidade adequada. A rota OSRM usa perfil de automóvel; restrições específicas de caminhões não fazem parte deste MVP. A proximidade entre prestador e origem usa distância geográfica, não tempo de deslocamento.

Referências: [Nominatim — política de uso](https://operations.osmfoundation.org/policies/nominatim/), [OSRM — Route service](https://project-osrm.org/docs/v5.24.0/api/), [OpenStreetMap — tiles](https://operations.osmfoundation.org/policies/tiles/).

## PostgreSQL / Supabase

O script original em `BANCO` começa removendo tabelas. Ele **não é executado** pelo MVP. A nova migração está em `backend/migrations/001_mvp.sql` e usa `CREATE TABLE IF NOT EXISTS` no schema `leva_ai_mvp`, preservando o schema público existente. Não houve migração nem alteração remota no Supabase.

Para conectar:

1. Em `backend`, execute `npm ci` e copie `.env.example` para `.env`.
2. Preencha `DATABASE_URL` com uma conexão PostgreSQL de servidor autorizada. No Supabase, prefira conexão direta ou pooler em modo **session**, pois o adaptador mantém `search_path` na sessão.
3. Use TLS válido conforme a conexão do provedor; não desative verificação de certificados.
4. Inicie a API. Ela cria seu schema e tabelas se ainda não existirem. Não importa dados das tabelas originais automaticamente.

O esquema separa usuários, sessões, veículos, orçamentos, reservas, pagamentos, avaliações e histórico, com chaves estrangeiras e índice único parcial de reserva. Detalhes variáveis da carga/rota/veículo e snapshots de preços são JSON em colunas TEXT portáveis entre bancos. É uma escolha de simplicidade do MVP; itens/endereço podem ser normalizados em futuras migrações. O banco é acessado somente pelo servidor, nunca diretamente pelo Flutter. Não exponha esse schema via PostgREST nem credenciais de banco no cliente.

## Pix

**O modo padrão é demonstrativo e não gera cobrança nem QR Code pagável.** A confirmação simulada fica identificada na interface e no banco.

O adaptador para Mercado Pago cria Pix com `X-Idempotency-Key` por pedido e consulta o estado no servidor, conferindo valor, moeda, método e referência antes de agendar. Para habilitar, configure `DEMO_MODE=false`, `DATABASE_URL`, `JWT_SECRET` aleatório de pelo menos 32 caracteres e `MERCADO_PAGO_ACCESS_TOKEN` em `backend/.env`. Utilize um banco novo, sem as contas de demonstração, para ambiente real. A conta deve estar habilitada para Pix e o gateway pode exigir adequações aos dados do pagador de acordo com sua conta. Nenhuma chave privada vai para o Flutter.

O adaptador real foi implementado a partir da [documentação de Pix do Mercado Pago](https://www.mercadopago.com.br/developers/pt/docs/checkout-bricks/payment-brick/payment-submission/pix), mas **não foi homologado com uma conta ou transação real**. A confirmação usa o botão **Consultar pagamento**. Webhooks, conciliação automática, expiração de reservas, reembolso, split e repasse ao prestador ainda precisam de implementação antes de uma operação comercial. Não há cartão neste MVP.

## Regras e limites desta versão

- Um veículo fica reservado por dia enquanto o pedido está aberto. Não há agenda por horário nem expiração automática; pedidos não respondidos precisam de cancelamento/recusa.
- A equipe de ajudantes é declarada por veículo. Não reutilize a mesma equipe em veículos simultâneos; gestão compartilhada de equipes fica para outra etapa.
- Cliente cancela enquanto aguarda aceite/pagamento e **antes da emissão do Pix**. Depois da emissão, cancelamento exige atendimento/conciliação; não há reembolso automático.
- Prestador só inicia depois da aprovação do Pix e segue a ordem dos status. A interface atualiza por ação explícita, sem rastreamento em tempo real.
- Itens e quantidades são texto descritivo; peso/volume são estimativas informadas pelo cliente. Dimensões individuais, pedágios, mínimo, taxa de retorno e restrições da via não compõem o preço.
- A API usa uma conexão e fila transacional por processo. Adequado à demonstração, sem promessa de escala: consultas externas podem atrasar outras requisições. Pool, transações com bloqueio por reserva e jobs são próximos passos.
- Edição completa de perfil, endereços favoritos, recuperação/verificação de e-mail, upload de fotos, chat e notificações ficam fora desta entrega.
- Não foi realizada adequação jurídica/LGPD para operação pública. Antes de publicar: termos, privacidade, retenção, atendimento e exclusão de dados, HTTPS, gestão de segredos, monitoramento e homologação das integrações.

## Validação

API: em `backend`, `npm test`. Cobre fluxo completo, preço, capacidade, disponibilidade, dados inválidos, isolamento entre usuários, concorrência, expiração, pagamento idempotente, cancelamento, recusa, avaliação e logout.

Flutter: em `frontEnd/leva_ai`, `flutter analyze`, `flutter test` e `flutter build web --release`. Testes de interface verificam erro de login, formulário e layouts de 390 e 1440 pixels. O fluxo de cliente/prestador também foi exercitado no navegador local.

PostgreSQL remoto e Pix real exigem validação com infraestrutura e credenciais de homologação. Os testes automatizados usam SQLite isolado em memória.
