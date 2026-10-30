# Riko Player

Aplicativo Android para reprodução e organização de músicas locais, desenvolvido com **Flutter e Dart**.

## Sobre o projeto

O Riko Player é um projeto pessoal de desenvolvimento de um player de música para Android, voltado à reprodução de arquivos de áudio armazenados no próprio dispositivo.

O aplicativo permite explorar a biblioteca musical, reproduzir músicas em segundo plano e organizar faixas em playlists personalizadas, sem depender de serviços de streaming ou conexão com a internet para reprodução.

O desenvolvimento prioriza organização do código, desempenho, gerenciamento de estado e integração com os recursos nativos do Android.

## Tecnologias utilizadas

- **Flutter e Dart** — desenvolvimento do aplicativo.
- **Material Design 3** — componentes e identidade visual.
- **device_audio_query** — consulta de músicas e metadados pelo Android MediaStore.
- **just_audio** — reprodução de áudio local.
- **audio_service** — reprodução em segundo plano, notificações e controles de mídia do Android.
- **audio_session** — configuração da sessão de áudio.
- **sqflite (SQLite)** — armazenamento local das playlists.
- **uuid** — geração de identificadores únicos para playlists.
- **ChangeNotifier** — gerenciamento de estado e comunicação entre controllers e interface.

## Funcionalidades implementadas

### Interface e navegação

- Tema escuro com identidade visual roxa.
- Navegação entre Biblioteca e Playlists.
- Tela de Configurações.
- Miniplayer integrado à navegação.
- Tela completa de reprodução.
- Interface adaptada para dispositivos Android.

### Biblioteca de músicas

- Leitura automática das músicas armazenadas no dispositivo.
- Exibição de título, artista e duração.
- Exibição das capas dos álbuns, quando disponíveis.
- Ícone padrão para músicas sem capa.
- Pesquisa por título e artista.
- Atualização manual e automática da biblioteca.
- Tratamento de permissões, carregamento e erros.
- Integração com o Android MediaStore.

### Reprodução de áudio

- Reprodução de músicas locais utilizando `just_audio`.
- Reprodução a partir da biblioteca ou de playlists.
- Controles de reproduzir, pausar, avançar e voltar.
- Fila de reprodução sequencial.
- Miniplayer com informações da música e controles.
- Barra de progresso no miniplayer.
- Tela completa com barra de progresso interativa.
- Preservação da reprodução durante a navegação pelo aplicativo.
- Tratamento de erros e operações assíncronas.

### Reprodução em segundo plano

- Reprodução contínua com o aplicativo minimizado.
- Reprodução com a tela do dispositivo bloqueada.
- Notificação de mídia com título, artista e capa.
- Controles de reprodução na notificação do Android.
- Controles de mídia na tela de bloqueio.
- Sincronização entre os controles do sistema e do aplicativo.
- Preservação da fila e da posição de reprodução ao alternar entre aplicativos.
- Gerenciamento de foco de áudio e interrupções.
- Integração com serviço de mídia em primeiro plano no Android.

### Playlists

- Criação de playlists personalizadas.
- Renomeação de playlists.
- Exclusão de playlists mediante confirmação.
- Adição de múltiplas músicas de uma só vez.
- Remoção de músicas das playlists.
- Reorganização manual por arrastar e soltar (*drag and drop*).
- Ordenação alfabética por título ou artista.
- Persistência da ordem das músicas.
- Reprodução de playlists completas ou a partir de uma faixa específica.
- Armazenamento local utilizando SQLite.
- Tratamento de músicas removidas ou indisponíveis.
- Preservação da fila em reprodução durante alterações nas playlists.

As playlists armazenam referências às músicas do dispositivo, sem duplicar ou modificar os arquivos de áudio.

### Desempenho e gerenciamento de recursos

- Construção sob demanda dos itens da biblioteca utilizando `SliverList.builder`.
- Carregamento de capas conforme os itens são exibidos.
- Cache LRU de capas com limites de memória.
- Reaproveitamento de consultas de capas em andamento.
- Atualização da biblioteca sem interromper a exibição da lista.
- Preservação do estado dos itens durante pesquisas.
- Reutilização de uma única instância de `AudioPlayer`.
- Proteções contra operações assíncronas concorrentes.
- Operações transacionais no banco de dados.
- Integridade referencial e controle de duplicatas nas playlists.

## Arquitetura

O projeto utiliza uma organização modular por funcionalidades, separando responsabilidades entre interface, lógica de negócio, modelos e acesso a dados.

Os principais módulos são:

- **Library:** consulta e gerenciamento da biblioteca musical.
- **Playback:** reprodução de áudio, fila, estado e integração com os controles do Android.
- **Playlists:** gerenciamento, persistência e reprodução de playlists.
- **Core:** recursos compartilhados, incluindo o tema do aplicativo.
- **App:** inicialização, configuração e navegação.

O gerenciamento de estado utiliza `ChangeNotifier`, enquanto a reprodução é centralizada em uma única instância de `AudioPlayer`.

O `PlaybackController` gerencia a fila e o estado da reprodução. O `RikoAudioHandler` integra esses recursos aos controles de mídia do Android.

As playlists possuem persistência independente, permitindo que sejam editadas sem alterar a fila que já está em reprodução.

## Pré-requisitos

- Flutter SDK instalado e configurado.
- Android SDK.
- Android Studio ou VS Code.
- Dispositivo Android ou emulador compatível.

## Instalação

Clone o repositório:

```bash
git clone https://github.com/mauriciohx350-spec/Riko-Player.git
```

Acesse a pasta do projeto:

```bash
cd Riko-Player
```

Instale as dependências:

```bash
flutter pub get
```

Execute o aplicativo em um dispositivo conectado:

```bash
flutter run
```

## Testes e validação

O projeto possui testes automatizados para os principais componentes, incluindo reprodução, gerenciamento de estado, persistência e operações com playlists.

Para executar os testes:

```bash
flutter test
```

Para verificar possíveis problemas no código:

```bash
flutter analyze
```

Para gerar um APK de depuração:

```bash
flutter build apk --debug
```

**Última validação da etapa 7:**

- `dart format` — concluído.
- `flutter analyze` — sem apontamentos.
- `flutter test` — 67 testes aprovados.
- `flutter build apk --debug` — compilação concluída.

As funcionalidades principais também foram testadas em um dispositivo Android físico.

## Próximas funcionalidades

O desenvolvimento continuará com:

- Reprodução aleatória (*shuffle*).
- Modos de repetição de música e fila.
- Melhorias nas configurações do player.
- Refinamentos de desempenho e estabilidade.
- Reformulação da interface e melhorias de experiência do usuário.

## Status do projeto

**Em desenvolvimento.**

A biblioteca musical, a reprodução de áudio, a integração com os controles de mídia do Android e o gerenciamento de playlists locais estão implementados.

O projeto segue em desenvolvimento..
