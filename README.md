# 🚚 LevaAí

## MVP funcional

O MVP foi implementado neste repositório com **Flutter Web + Cloudflare Worker + PostgreSQL no Supabase**. Inclui cadastro/login, veículos, cotação, contratação, aceite/recusa, Pix demonstrativo, status, histórico e avaliações.

Na raiz do projeto, execute `./Iniciar-MVP.ps1` e abra **http://127.0.0.1:3000**. As contas de teste estão disponíveis nos botões **Testar cliente** e **Testar prestador**. Para recompilar: `./Iniciar-MVP.ps1 -Recompilar`.

Consulte o **[guia completo do MVP](docs/MVP.md)** para o roteiro de apresentação, configuração da Cloudflare e Supabase, mapas, Pix e limitações. O Pix real depende de configuração e homologação; o modo padrão não gera cobranças. O banco remoto existente não foi alterado.

---

> Plataforma digital para intermediação e pareamento logístico inteligente entre prestadores de serviço de frete e clientes finais.

O **LevaAí** é uma aplicação desenvolvida como Trabalho de Conclusão de Curso (TCC) voltada para a modernização do setor de carretos e mudanças. O sistema funciona como um catálogo interativo e inteligente, conectando usuários que precisam transportar itens a fretadores autônomos com veículos adequados à demanda específica (capacidade de carga, cubagem e porte).

---

## 📱 Protótipo da Interface

O design e fluxo de telas da aplicação foram construídos no Figma:
* [Acessar protótipo no Figma](https://www.figma.com/design/dlXG86eOCCoe8pWrFQw1gq/TCC?node-id=0-1&p=f)

**Módulos mapeados no protótipo:**
* Onboarding e Apresentação
* Autenticação e Perfis (Cliente / Fretador)
* Catálogo / Painel de Serviços com Filtros Avançados
* Histórico de Transportes e Pedidos
* Gestão de Endereços

---

## 🏛️ Arquitetura do Frontend

O projeto mobile foi construído em **Flutter**, adotando os padrões de **Clean Architecture** em conjunto com **MVVM (Model-View-ViewModel)** para garantir desacoplamento, testabilidade e manutenibilidade:

```text
lib/
├── core/                  # Recursos globais, erros, tema e injeção de dependências
│   ├── constants/
│   ├── di/
│   ├── errors/
│   ├── network/
│   └── theme/
├── data/                  # Implementações concretas de acesso a dados
│   ├── datasources/       # Chamadas a APIs externas e fontes locais
│   ├── models/            # DTOs e serialização JSON
│   └── repositories/      # Implementação dos contratos de repositório
├── domain/                # Regras de negócio puras (sem dependência de UI)
│   ├── entities/          # Modelos de domínio puros
│   ├── repositories/      # Contratos e interfaces abstratas
│   └── usecases/          # Casos de uso do sistema
└──
# LevaAi-MVP
