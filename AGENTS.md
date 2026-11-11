# Repository Guidelines — ViaCidadã Mobile

## Project Structure & Module Organization

ViaCidadã Mobile é um aplicativo multiplataforma desenvolvido com Flutter e Dart 3, projetado para consumir a API REST ViaCidadã (Java/Spring Boot) e apoiar a mobilidade urbana e acessibilidade no transporte público (tema CitizenTech).

O código-fonte da aplicação reside sob a pasta `lib/`, organizado por responsabilidade arquitetural:
- `lib/main.dart`: Ponto de entrada do app (`main()`), inicialização de temas e rotas.
- `lib/models/`: Classes de domínio/dados que modelam os objetos recebidos da API (DTOs/Entidades convertidos de/para JSON).
- `lib/services/`: Camada de comunicação de rede (requisições HTTP, autenticação JWT, integração com o backend).
- `lib/screens/` (ou `pages/`): Telas visuais da aplicação (mínimo de 5 telas com navegação e passagem de parâmetros).
- `lib/widgets/`: Componentes visuais reutilizáveis (cards, botões customizados, formulários).
- `lib/constants/` ou `theme/`: Cores, tipografia, temas claros/escuros e constantes de API.

As pastas `android/`, `ios/`, `web/`, `windows/`, `linux/` e `macos/` contêm os projetos hospedeiros nativos gerados pelo Flutter SDK e **não** devem ser alteradas manualmente a menos que seja para configurar permissões específicas (como acesso à internet).

## Build, Test, and Development Commands

Utilize o Flutter CLI para compilar, testar e executar a aplicação:

```powershell
flutter run                  # Executa o app (no navegador Chrome, emulador ou dispositivo conectado)
flutter test                 # Executa os testes de unidade e de widgets
flutter pub get              # Baixa as dependências declaradas no pubspec.yaml
flutter build web            # Gera os arquivos estáticos de produção para a Web
```

Durante a execução com `flutter run`, utilize os comandos de desenvolvimento no terminal:
- `r`: **Hot Reload** (recarrega alterações visuais instantaneamente sem perder o estado da tela).
- `R`: **Hot Restart** (reinicia o app do zero, limpando o estado).
- `q`: Encerra a execução.

## Coding Style & Naming Conventions

Siga rigorosamente as convenções oficiais do Dart/Flutter:
- **Arquivos e pastas**: sempre em `snake_case` (ex.: `login_screen.dart`, `occurrence_service.dart`).
- **Classes, Enums e Widgets**: `PascalCase` (ex.: `OccurrenceScreen`, `AuthService`).
- **Variáveis, métodos e parâmetros**: `camelCase` (ex.: `fetchOccurrences()`, `userToken`).
- **Constantes**: `camelCase` ou `lowerCamelCase` com `const` (padrão oficial de Dart).
- Prefira widgets puros e modulares; extraia widgets longos em componentes reutilizáveis para manter o método `build()` legível e limpo.

## Testing Guidelines

Os testes utilizam o pacote oficial `flutter_test`. 
- Testes unitários para validar lógica de negócio, parsing de JSON e serviços.
- Testes de widgets (`testWidgets`) para verificar a renderização de elementos na tela e simulação de toques e digitação.
- Execute sempre `flutter test` antes de submeter alterações.

## Educational Pair Programming & Architecture Mentorship (Mentoria e Explicação Didática)

O desenvolvedor deste projeto é um programador iniciante em fase de aprendizado de desenvolvimento mobile, ecossistema Flutter/Dart, arquitetura de software e boas práticas. Além disso, **este projeto será apresentado e defendido perante professores e bancas acadêmicas (Global Solution FIAP 2TDS)**. Portanto, a velocidade de geração de código nunca deve atropelar o aprendizado: o desenvolvedor precisa ter total consciência e domínio de cada etapa, decisão e linha implementada.

Ao trabalhar neste repositório, o agente deve seguir rigorosamente as seguintes diretrizes pedagógicas:

1. **Explicar o Papel de Cada Camada e Arquivo**:
   - Sempre que criar ou alterar código, descreva explicitamente em qual camada ele reside (`screens`, `widgets`, `services`, `models`, `theme`, etc.) e qual é a sua única responsabilidade.
   - Reforce conceitos de arquitetura limpa, composição de widgets e Separação de Responsabilidades (SRP/SOLID) de forma prática.

2. **Justificar o "Porquê" de Cada Decisão Técnica**:
   - Não apenas mostre *o que* foi feito, mas explique *por que* essa solução foi adotada em comparação a alternativas (ex.: por que usamos `StatelessWidget` para elementos estáticos e `StatefulWidget` com `setState()` quando há dados que mudam? Por que isolar chamadas de API em uma classe `Service` em vez de fazer `http.get` dentro do botão na tela? Por que usar `TextFormField` com `validator` e `GlobalKey<FormState>` em vez de apenas `TextField` solto?).
   - Ensine o desenvolvedor a pensar criticamente e a tomar decisões arquiteturais por conta própria.

3. **Didática e Linguagem Acessível (sem perder a excelência técnica)**:
   - Responda e explique sempre em português claro, direto e didático, usando analogias simples quando o conceito for abstrato (ex.: comparar Widgets a blocos de LEGO e o `build()` à montagem da cena).
   - **Não reduza a qualidade do código**: continue aplicando rigorosamente as melhores metodologias (Clean Code, Design Patterns, tratamento de estados de carregamento e erro, validação de formulários, feedback visual ao usuário com SnackBar/Dialog). O objetivo é **elevar o conhecimento do desenvolvedor até o nível da solução**, e não nivelar a solução por baixo.

4. **Preparação para Apresentação Acadêmica (Argumentação para Professores)**:
   - Ao finalizar cada funcionalidade relevante ou tela, inclua um bloco rápido de orientação para a banca:
     - **Resumo do que foi feito**: Síntese executiva da feature.
     - **Como defender para o professor**: 1 a 3 argumentos técnicos sólidos caso os professores perguntem o motivo daquela abordagem ou a vantagem arquitetural daquela decisão (ex.: cumprimento dos requisitos da GS: fluxo de navegação, passagem de parâmetros, gerenciamento de estado e formulário).

5. **Passo a Passo Consciente**:
   - Em tarefas complexas ou estruturais, quebre a implementação em etapas claras para que o desenvolvedor acompanhe a evolução do raciocínio em vez de receber um bloco maciço e hermético de código sem contexto.
