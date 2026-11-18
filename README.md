# ViaCidadã Mobile — Global Solution FIAP 2026/2 (CitizenTech)

> **Disciplina:** Mobile Application Development | **Tema:** CitizenTech — Mobilidade Urbana Acessível

Aplicativo multiplataforma em **Flutter e Dart 3** que conecta cidadãos — com foco especial em **Pessoas com Deficiência (PcD)** e usuários com mobilidade reduzida — ao transporte público acessível, planejamento multimodal de rotas, previsão de chegada em tempo real (SPTrans Olho Vivo) e registro colaborativo de ocorrências urbanas.

O aplicativo consome diretamente a API REST em Java/Spring Boot ([gs-java-api](https://github.com/GS-EDUeAMIGOS/gs-java-api)) e também possui fallback local em memória no `ApiService` para garantir demonstração funcional mesmo caso o backend não esteja em execução.

---

## 1. Equipe, Vídeo e ODS da ONU

### Integrantes do Grupo

| Nome Completo | RM | Turma |
|---|---|---|
| Alisson Kawan Evangelista Silva | 567598 | 2TDS |
| Kenji Fernandes Wakabayashi | 568156 | 2TDS |
| Erick Ramos Santos | 567837 | 2TDS |
| Eduardo Boni dos Santos | 567236 | 2TDS |
| Marcos Vinicius de Jesus Almeida | 567214 | 2TDS |

### Vídeo de Demonstração (Emulador / Dispositivo Físico)
- **Link do Vídeo (YouTube Não Listado — até 5 min):** https://www.youtube.com/watch?v=BxIJTXHqGcU

### Cidadão Beneficiado & Conexão com os ODS (ONU)
- **Cidadão Beneficiado:** Passageiros do transporte público urbano, especialmente Pessoas com Deficiência (PcD), idosos e pessoas com mobilidade reduzida que dependem de veículos com elevador/rampa acessível e infraestrutura adequada nas paradas.
- **ODS 10 — Redução das Desigualdades:** Promove autonomia e inclusão no deslocamento diário ao destacar ônibus acessíveis e alertas críticos em tempo real.
- **ODS 11 — Cidades e Comunidades Sustentáveis (Meta 11.2):** Contribui para sistemas de transporte seguros, acessíveis e sustentáveis com participação cidadã.

---

## 2. Arquitetura, Telas e Requisitos Atendidos

```text
lib/
 ├─ main.dart         # MaterialApp, tema global e tabela de rotas nomeadas
 ├─ models/           # Modelos de domínio (AuthUser, OcorrenciaModel, OlhoVivoModel)
 ├─ services/         # ApiService (HTTP/JWT + fallback offline), LocationService (GPS)
 ├─ screens/          # 8 telas conectadas por navegação fluida e passagem de parâmetros
 ├─ widgets/          # Componentes reutilizáveis (OccurrenceCard, PontoMapWidget, marcadores)
 └─ theme/            # Identidade visual consistente (AppTheme e MapTheme)
```

### Fluxo das 8 Telas (mínimo exigido: 5)
1. **`/login` (`LoginScreen`)**: Autenticação JWT (`POST /api/auth/login`), cadastro de cidadão (`POST /api/auth/register`) com `Form` + `GlobalKey<FormState>` e opção de acesso rápido em modo visitante.
2. **`/home` (`HomeScreen`)**: Painel principal com atalhos rápidos (`GridView`), busca rápida de destinos e lista de alertas críticos de acessibilidade (`ListView`).
3. **`/occurrences` (`OccurrencesScreen`)**: Listagem completa de ocorrências com filtros dinâmicos (`setState()`), busca textual e remoção.
4. **`/occurrence-detail` (`OccurrenceDetailScreen`)**: Detalhamento da ocorrência recebida via passagem de parâmetros (`ModalRoute.of(context)?.settings.arguments`).
5. **`/occurrence-form` (`OccurrenceFormScreen`)**: Formulário completo com `TextFormField`, `DropdownButtonFormField`, `SwitchListTile`, `GlobalKey<FormState>`, validações alinhadas ao backend e feedback imediato via `SnackBar`.
6. **`/sptrans` (`SptransScreen`)**: Consulta ao radar de linhas, paradas e previsão de chegada em tempo real com mapa interativo.
7. **`/route-planner` (`RoutePlannerScreen`)**: Planejador de rotas estilo Moovit com suporte a GPS e baldeação.
8. **`/route-navigation` (`RouteNavigationScreen`)**: Navegação ativa da rota selecionada em mapa dark mode.

---

## 3. Como Executar e Testar

### Pré-requisitos
- **Flutter SDK 3.x** / **Dart 3.x**
- Emulador Android, dispositivo físico ou Chrome/Desktop para testes

### Comandos

```powershell
# 1. Instalar dependências
flutter pub get

# 2. Executar os testes automatizados de widgets
flutter test

# 3. Rodar o aplicativo (emulador Android ou dispositivo conectado)
flutter run
```

> **Usuários de teste:** `cidadao@viacidada.com.br` / `Cidadao@123` (`ROLE_CIDADAO`) e `admin@viacidada.com.br` / `Admin@123` (`ROLE_ADMIN`).

---

## 4. Declaração de Uso de IA Generativa

Em conformidade com as diretrizes da Global Solution FIAP 2026/2:
- **Ferramentas utilizadas:** Assistente de programação com IA integrado à IDE (Antigravity / Gemini) para apoio na estruturação inicial de camadas, revisão de validações, testes de widgets e organização da documentação (`README.md`).
- **Supervisão humana:** Todo o código, fluxo de navegação, gerenciamento de estado (`StatefulWidget` / `setState`) e integração com a API Java foram revisados, testados e validados pela equipe.

---

## 5. Repositórios Relacionados da GS
- [gs-java-api](https://github.com/GS-EDUeAMIGOS/gs-java-api) — Java Advanced (API REST consumida por este app)
- [gs-dotnet-api](https://github.com/GS-EDUeAMIGOS/gs-dotnet-api) — Advanced Business Development with .NET
- [gs-arquitetura-qa](https://github.com/GS-EDUeAMIGOS/gs-arquitetura-qa) — Compliance, Quality Assurance & Tests
- [gs-devops-cloud](https://github.com/GS-EDUeAMIGOS/gs-devops-cloud) — DevOps Tools & Cloud Computing
- [gs-iot-redes](https://github.com/GS-EDUeAMIGOS/gs-iot-redes) — Disruptive Architectures: IoT, IoB & Generative IA
- [gs-database](https://github.com/GS-EDUeAMIGOS/gs-database) — Mastering Relational and Non-Relational Database
