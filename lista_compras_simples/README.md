# Lista de Tarefas - Aplicativo Flutter

Aplicativo profissional de gerenciamento de tarefas desenvolvido em Flutter com Material Design 3.

---

# Relatório - Laboratório 3: Recursos Nativos (Câmera, Sensores, GPS)

## Funcionalidades AULA 3 Implementadas

### Sistema de Câmera e Galeria

- **Captura de Fotos**: Integração com câmera nativa (Android/iOS) usando `camera` package
- **Galeria de Fotos**: Seleção de imagens existentes com `image_picker`
- **Múltiplas Fotos por Tarefa**: Suporte para anexar várias imagens
- **Visualização em Grid**: Interface visual para gerenciar fotos das tarefas
- **Exclusão de Fotos**: Remover fotos individuais ou múltiplas
- **Armazenamento Local**: Salvamento persistente em diretório da aplicação

### Filtros de Foto (Atividade Extra)

- **8 Filtros Disponíveis**: Nenhum, P&B, Sépia, Inverter, Brilho+, Brilho-, Contraste+, Contraste-, Blur, Sharpen
- **Preview Interativo**: Visualização em tempo real dos filtros antes de aplicar
- **Interface Horizontal**: Scroll horizontal para seleção fácil de filtros
- **Aplicação em Tempo Real**: Filtros aplicados antes de salvar a foto
- **Multiplataforma**: Funciona em Android, iOS e Windows (processamento puro Dart)

### Sistema de Localização (GPS)

- **Captura de Coordenadas**: Integração com GPS para obter latitude/longitude
- **Geocodificação**: Conversão de coordenadas para endereços legíveis
- **API Nominatim**: Geocoding cross-platform usando OpenStreetMap
- **Picker de Localização**: Widget adaptável para definir localização de tarefas
- **Validação de Permissões**: Gerenciamento de permissões de localização

### Geofencing com Notificações (Atividade Extra)

- **Monitoramento de Área**: Raio de 100m ao redor de tarefas com localização
- **Notificações de Entrada**: Alerta quando usuário entra no raio da tarefa
- **Notificações de Saída**: Alerta quando usuário sai do raio da tarefa
- **Ícones Contextuais**: 📍 para entrada, 🚶 para saída
- **Plataforma**: Android/iOS apenas (requer GPS contínuo)

### Histórico de Localizações (Atividade Extra)

- **Rastreamento Automático**: Salva todas as localizações onde tarefa foi acessada
- **Timestamp Completo**: Data e hora de cada acesso
- **Coordenadas**: Latitude e longitude armazenadas
- **Endereço Legível**: Geocodificação reversa para cada entrada
- **Multiplataforma**: Funciona em todas as plataformas (Android, iOS, Windows)

### Sensores e Feedback Háptico

- **Acelerômetro**: Detecção de movimento para shake
- **Shake para Backup**: Agitar o dispositivo para fazer backup rápido
- **Long Shake**: Agitar por 3 segundos para ações especiais
- **Vibração**: Feedback tátil ao detectar shake
- **Plataforma**: Android/iOS apenas (sensores físicos)

## Arquitetura de Serviços (AULA 3)

### CameraService

- Singleton para gerenciamento centralizado
- Inicialização assíncrona de câmeras disponíveis
- Métodos: `takePicture()`, `pickFromGallery()`, `pickMultipleFromGallery()`
- Navegação para tela customizada de câmera
- Salvamento automático com nomenclatura única

### PhotoFilterService (Extra)

- Aplicação de 8 filtros diferentes
- Algoritmos customizados (matriz sépia, blur, sharpen)
- Geração de previews em baixa resolução (200px)
- Encoding JPG com qualidade 85
- Processamento assíncrono para performance

### LocationService

- Verificação de permissões e serviços
- Captura de posição atual com GPS
- Geocodificação usando Nominatim API (cross-platform)
- Geofencing com raio configurável (100m)
- Monitoramento contínuo de posição
- Callbacks para eventos de entrada/saída

### SensorService

- Detecção de shake com acelerômetro
- Calibração de magnitude (15.0 threshold)
- Debounce de 500ms entre shakes
- Timer de 3 segundos para long shake
- Vibração customizada (pattern: 0ms, 200ms, 100ms, 200ms)

### NotificationService (Estendido)

- Canal específico para geofencing
- Notificações com cores e ícones customizados
- Prioridade alta para alertas de localização
- Método `showGeofenceNotification(taskTitle, entered)`

## Integrações AULA 3

### Tela de Câmera (CameraScreen)

- Preview em tempo real da câmera
- Controle de flash (auto, on, off)
- Troca entre câmera frontal/traseira
- Botão de captura com animação
- Salvamento automático após captura
- Feedback visual de sucesso

### Tela de Filtros (PhotoFilterScreen)

- Grid horizontal de previews de filtros
- Seleção visual com borda destacada
- Aplicação do filtro selecionado
- Indicador de progresso durante processamento
- Retorno do caminho da foto filtrada

### Formulário de Tarefa (TaskFormScreen)

- Seção de fotos com grid visual
- Opções: Tirar Foto / Escolher da Galeria
- Dialog para escolher se aplica filtro
- Visualização de fotos em grid 3 colunas
- Exclusão de fotos individuais
- Widget de Localização integrado
- Histórico de localizações salvo automaticamente

### Lista de Tarefas (TaskListScreen)

- Setup de geofencing no `initState()`
- Atualização de geofences após carregar tarefas
- Stop de monitoramento no `dispose()`
- Callback para notificações de geofence
- Detecção de shake para backup rápido

## Banco de Dados - Migração v5

```sql
ALTER TABLE tasks ADD COLUMN photos TEXT;           -- JSON array de caminhos
ALTER TABLE tasks ADD COLUMN location TEXT;         -- JSON {lat, lng, address}
ALTER TABLE tasks ADD COLUMN locationHistory TEXT;  -- JSON array de histórico
```

### Estrutura de Dados

**Photos**: `["path/to/photo1.jpg", "path/to/photo2.jpg"]`

**Location**: `{"latitude": -23.5505, "longitude": -46.6333, "address": "São Paulo, SP"}`

**LocationHistory**:

```json
[
  {
    "timestamp": "2025-11-09T14:30:00.000",
    "latitude": -23.5505,
    "longitude": -46.6333,
    "address": "São Paulo, SP, Brasil"
  }
]
```

## Estratégia Cross-Platform

### ✅ Funciona em Windows

- ✅ Galeria de fotos (image_picker)
- ✅ GPS e geocodificação (Nominatim API)
- ✅ Histórico de localizações
- ✅ Armazenamento de fotos

### ⚠️ Apenas Mobile (Android/iOS)

- ⚠️ Câmera nativa (camera package)
- ⚠️ Sensores (acelerômetro)
- ⚠️ Vibração
- ⚠️ Geofencing contínuo

### Proteções Implementadas

```dart
if (Platform.isAndroid || Platform.isIOS) {
  // Código específico de hardware
}
```

Todas as features de hardware têm checks de plataforma para não quebrar em Windows.

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

### AULA 3 - Recursos Nativos

- **camera** ^0.10.5+9 - Câmera nativa (Android/iOS)
- **image_picker** ^1.0.7 - Galeria e picker de imagens
- **sensors_plus** ^4.0.2 - Acelerômetro e sensores
- **vibration** ^1.8.4 - Feedback háptico
- **geolocator** ^10.1.0 - GPS e localização
- **geocoding** ^2.1.1 - Geocodificação
- **http** ^1.1.0 - Requisições HTTP (Nominatim API)
- **image** ^4.1.3 - Processamento de imagens e filtros

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
