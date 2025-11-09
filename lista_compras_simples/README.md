# Lista de Tarefas - Aplicativo Flutter

Aplicativo profissional de gerenciamento de tarefas desenvolvido em Flutter com Material Design 3.

---

# Relatório - Laboratório 2: Interface Profissional

## 1. Implementações Realizadas

### Principais Funcionalidades

- **Gerenciamento Completo de Tarefas**: CRUD completo (Create, Read, Update, Delete) de tarefas
- **Sistema de Categorias**: Organização de tarefas por categorias personalizáveis com ícones e cores
- **Níveis de Prioridade**: 4 níveis (Baixa, Média, Alta, Urgente) com indicadores visuais
- **Datas de Vencimento**: Agendamento de tarefas com validação de datas vencidas
- **Sistema de Lembretes**: Notificações locais integradas para alertas de tarefas
- **Filtros Avançados**: Filtros por status (Todas, Pendentes, Concluídas, Vencidas) e categoria
- **Ordenação Múltipla**: Ordenar por vencimento, prioridade, título ou data de criação
- **Backup e Restore**: Exportação/importação de dados em formato JSON
- **Compartilhamento**: Compartilhar tarefas individuais ou listas filtradas
- **Estatísticas em Tempo Real**: Dashboard com contadores de tarefas por status

### Componentes Material Design 3 Utilizados

- **Cards**: Exibição de tarefas com elevação e bordas arredondadas
- **FloatingActionButton**: Botão de ação principal para criar tarefas
- **BottomSheet**: Menu de opções ao fazer long press nos cards
- **Chips**: Indicadores de prioridade e categoria
- **Dropdowns**: Seleção de filtros, categorias e prioridades
- **TextFormField**: Formulários validados para entrada de dados
- **Checkbox**: Marcação de tarefas como concluídas
- **ListTile**: Itens de lista padronizados
- **AppBar**: Barra superior com ações contextuais
- **SnackBar**: Feedback visual de ações realizadas
- **AlertDialog**: Confirmações e validações
- **PopupMenuButton**: Menu de opções em cards e AppBar
- **IconButton**: Botões de ação secundários
- **CircularProgressIndicator**: Indicadores de carregamento

### Banco de Dados

- **SQLite (sqflite)**: Persistência local de dados
- **Tabelas**: `tasks` e `categories` com relacionamentos
- **Operações assíncronas**: Queries otimizadas para performance

### Notificações

- **flutter_local_notifications**: Sistema de lembretes configurável
- **Agendamento**: Notificações programadas por data/hora
- **Alertas de vencimento**: Notificações automáticas para tarefas vencidas

## 2. Desafios Encontrados

### Overflow em Dropdowns

**Problema**: Dropdowns de categoria transbordavam pixels em telas pequenas devido ao tamanho do ícone + texto + padding.

**Solução**:

- Redução do espaçamento entre ícone e texto (8px → 2px)
- Implementação de `isExpanded: true` nos DropdownButtonFormField
- Adição de `overflow: TextOverflow.ellipsis` nos textos
- Redução do `contentPadding` de 12px para 8px

### Cache do CMake

**Problema**: Erro de incompatibilidade de paths ao mover projeto entre diretórios.

**Solução**: Limpeza completa da pasta `build/windows` para regenerar cache do CMake com os paths corretos.

### Gestão de Estado

**Problema**: Sincronização entre lista de tarefas e categorias após updates.

**Solução**: Uso consistente de `setState()` e recarregamento de dados após operações CRUD usando `mounted` checks.

### Long Press vs Tap

**Problema**: Comportamento conflitante entre clique simples e long press no card.

**Solução**:

- Clique simples: marca/desmarca tarefa (ação mais frequente)
- Long press: abre menu de opções
- Menu de opções também acessível pelo botão de 3 pontos

## 3. Melhorias Implementadas

### Além do Roteiro Básico

1. **Sistema de Backup Profissional**

   - Exportação para JSON com validação
   - Importação com verificação de integridade
   - Diálogo de confirmação com avisos
   - Compartilhamento via Share API

2. **Dashboard de Estatísticas**

   - Cards horizontais roláveis com métricas
   - Contadores coloridos por status
   - Indicadores especiais para urgentes e vencidas
   - Atualização em tempo real

3. **Compartilhamento Rico**

   - Formatação em Markdown para compartilhamento
   - Preview antes de compartilhar
   - Inclusão de emojis e formatação
   - Compartilhar listas filtradas

4. **UX/UI Aprimorada**

   - Bordas coloridas nos cards por prioridade
   - Badges de categoria com cores personalizadas
   - Indicadores visuais para tarefas vencidas/hoje
   - Animações suaves com InkWell
   - Layout responsivo (adaptável para telas pequenas)

5. **Validações Robustas**
   - Validação de formulários com mensagens claras
   - Verificação de integridade em imports
   - Tratamento de erros com try-catch
   - Feedback visual para todas as operações

### Customizações

- **Tema**: Paleta de cores profissional com azul primário
- **Tipografia**: Hierarquia clara de fontes e tamanhos
- **Espaçamento**: Sistema consistente de 8px base
- **Ícones**: Biblioteca completa de ícones contextuais
- **Feedback**: SnackBars personalizados com cores semânticas

## 4. Aprendizados

### Principais Conceitos

1. **Arquitetura em Camadas**

   - Separação de models, services, screens e widgets
   - Responsabilidade única para cada componente
   - Reutilização de código

2. **Gestão de Estado**

   - StatefulWidget vs StatelessWidget
   - Ciclo de vida (initState, dispose, didUpdateWidget)
   - Uso correto de setState()

3. **Persistência de Dados**

   - SQLite para dados estruturados
   - Operações assíncronas com Future/async/await
   - Relacionamentos entre tabelas

4. **Material Design 3**

   - Sistema de design consistente
   - Componentes prontos e personalizáveis
   - Acessibilidade e responsividade

5. **Boas Práticas**
   - Uso de const para otimização
   - Validação de `mounted` antes de setState
   - Tratamento de erros e edge cases
   - Código limpo sem comentários desnecessários

### Diferenças entre Lab 1 e Lab 2

| Aspecto         | Lab 1             | Lab 2                   |
| --------------- | ----------------- | ----------------------- |
| **Interface**   | Básica, funcional | Profissional, polida    |
| **Componentes** | Poucos widgets    | Biblioteca completa MD3 |
| **Navegação**   | Simples           | Contextual e intuitiva  |
| **Validação**   | Mínima            | Completa com feedback   |
| **Feedback**    | Básico            | Rico e visual           |
| **Layout**      | Fixo              | Responsivo              |
| **Estado**      | Simples           | Gerenciado corretamente |
| **Performance** | Não otimizado     | Keys, const, async      |

## 5. Próximos Passos

### Funcionalidades Planejadas

1. **Autenticação e Sincronização**

   - Login com Firebase Auth
   - Sincronização em nuvem (Firestore)
   - Backup automático na nuvem

2. **Temas e Personalização**

   - Modo escuro/claro
   - Temas personalizados pelo usuário
   - Escolha de cores de acento

3. **Produtividade Avançada**

   - Subtarefas (tarefas aninhadas)
   - Tags personalizadas
   - Anexos de arquivos/imagens
   - Notas de voz

4. **Gamificação**

   - Sistema de pontos e conquistas
   - Streaks de conclusão
   - Gráficos de produtividade
   - Metas semanais/mensais

5. **Colaboração**

   - Compartilhar listas com outros usuários
   - Atribuir tarefas a membros
   - Comentários e discussões
   - Histórico de alterações

6. **Integrações**
   - Google Calendar
   - Widgets de tela inicial
   - Atalhos rápidos
   - Wear OS support

### Melhorias Técnicas

- Implementar testes unitários e de widget
- Adicionar internacionalização (i18n)
- Otimizar queries do banco de dados
- Implementar cache de imagens
- Adicionar analytics
- CI/CD com GitHub Actions

---

## Tecnologias Utilizadas

- **Flutter** 3.x
- **Dart** 3.x
- **sqflite** - Banco de dados SQLite
- **intl** - Formatação de datas
- **share_plus** - Compartilhamento
- **flutter_local_notifications** - Notificações
- **path_provider** - Acesso ao sistema de arquivos
- **file_picker** - Seleção de arquivos

## Como Executar

```bash
# Clone o repositório
git clone https://github.com/ffmelo-coder/DAMD.git

# Entre na pasta do projeto
cd DAMD/lista_compras_simples

# Instale as dependências
flutter pub get

# Execute o aplicativo
flutter run
```

## Requisitos

- Flutter SDK 3.0 ou superior
- Dart 3.0 ou superior
- Android Studio / VS Code
- Emulador ou dispositivo físico

---

**Desenvolvido como parte do curso de Desenvolvimento de Aplicações Móveis e Distribuídas**
