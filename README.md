# viacidada_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# gs-mobile-flutter

**FIAP — Global Solution 2026/2 — CitizenTech**  
**Disciplina:** Mobile Application Development

> Estado: preparação documental inicial. Não há aplicação, testes executados, infraestrutura provisionada ou entrega concluída neste repositório.

## Finalidade e limites

Aplicativo Flutter/Dart com cinco telas, navegação, estado, formulário validado e vídeo em emulador/dispositivo.

Este repositório representa um **entregável acadêmico da GS**, não o produto completo nem um entregável do Challenge. Os sete repositórios devem representar a mesma solução CitizenTech (slide 20). A solução, o nome do grupo, os integrantes, RMs, turma e responsáveis ainda precisam de confirmação específica para esta GS.

Nenhum código, modelo de domínio ou identidade do Challenge foi copiado. Reutilização futura deve ter origem principal, versão e revisão combinadas; separar entregas não significa duplicar implementação sem controle.

## Fonte e prazo

Fonte primária fornecida pelo usuário: `2TDS Agosto - Global Solution 2026-2.pptx`, slides 67–80. Orientações gerais: slides 11–16 e 20; submissão: slides 81–85. A numeração é a posição real dos slides no PPTX, não o contador interno de cada disciplina.

- **Entrega indicada: 19/11/2026, até 23h55, no Portal FIAP** (slide 14).
- Cadastro do grupo indicado até **13/11/2026** (slides 12 e 14); notas do arquivo pedem confirmação desse prazo.
- Apresentações indicadas de **23 a 27/11/2026**; conferir modalidade e agenda com o professor.
- Este checklist é derivado do PPTX, não substitui rubrica final e instruções do Portal. O original não foi republicado.

## Escopo e checklist

Veja [requisitos da disciplina](docs/requisitos-gs.md) e [decisões e pendências](docs/pendencias.md).

Backend e banco não são exigidos na rubrica Mobile (slides 68 e 71). Entretanto, a apresentação de Java exige Mobile consumindo a API (slide 57). O projeto Flutter será adicionado depois; não há app executável nesta preparação.

## Equipe e responsabilidade

| Informação | Situação |
|---|---|
| Grupo, solução e cidadão beneficiado | A confirmar para a GS |
| Integrantes, RM e turma | A confirmar para a GS |
| Responsável principal desta disciplina | A confirmar — um único dono por tarefa |
| Revisor | A combinar conforme fronteiras afetadas |

Não interpretar membros da organização ou integrantes do Challenge como composição aprovada da GS. Documentar ODS e contribuição às metas conforme slide 11, usando fontes para alegações de impacto.

## Execução e testes

Ainda não há software executável. Na implementação, substituir esta seção por pré-requisitos e versões reais, configuração sem segredos, comandos reproduzíveis, dados sintéticos e resultados de testes efetivamente executados. Não há build ou teste aprovado apenas pela existência desta documentação.

## Evidências e submissão

Arquivo .txt com nome do grupo, nomes dos integrantes, link do vídeo e endereço do GitHub público (slide 79). Conferir identificação com RM e turma prevista na orientação geral quando aplicável.

Organização das evidências: [evidence/README.md](evidence/README.md). Orientações de submissão: [delivery/README.md](delivery/README.md). Links de vídeo, diagramas e publicação permanecem pendentes; nenhum artefato final foi gerado.

## Repositórios relacionados da GS

- [gs-dotnet-api](https://github.com/GS-EDUeAMIGOS/gs-dotnet-api) — Advanced Business Development with .NET
- [gs-arquitetura-qa](https://github.com/GS-EDUeAMIGOS/gs-arquitetura-qa) — Compliance, Quality Assurance & Tests
- [gs-devops-cloud](https://github.com/GS-EDUeAMIGOS/gs-devops-cloud) — DevOps Tools & Cloud Computing
- [gs-iot-redes](https://github.com/GS-EDUeAMIGOS/gs-iot-redes) — Disruptive Architectures: IoT, IoB & Generative IA
- [gs-java-api](https://github.com/GS-EDUeAMIGOS/gs-java-api) — Java Advanced
- [gs-database](https://github.com/GS-EDUeAMIGOS/gs-database) — Mastering Relational and Non-Relational Database

As referências acima organizam entregas; não significam que todas as aplicações serão serviços separados do produto. Registrar contratos entre Java/.NET, Banco, Mobile, IoT e DevOps antes de integrar.

## Contribuição e segurança

Veja [CONTRIBUTING.md](CONTRIBUTING.md). Não versionar senhas, tokens, strings de conexão reais ou dados pessoais de usuários. Exemplos devem usar valores fictícios.

A preparação não configura equipes, permissões, CODEOWNERS, proteção de branches, CI ou deploy. Repositório público não substitui entrega no Portal nem comprova atendimento da rubrica.

## Aplicativo Flutter

O código executável está em `lib/`. Para executar e testar:

```powershell
flutter pub get
flutter run
flutter test
```
