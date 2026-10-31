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
- Fila de reprodução sequencial ou aleatória (Shuffle).
- Repeat Off, All e One, com histórico de navegação.
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


## Shuffle e Repeat — etapa 8

O `PlaybackController` decide todas as transições. `PlaybackOrder` mantém a ordem efetiva por índices, o histórico e os ciclos; a fila original permanece imutável. O `just_audio` continua recebendo uma fonte por vez, com uma única instância de `AudioPlayer`, sem ativar seus modos nativos de Shuffle/Loop.

Os controles ficam somente na tela completa. Os estados ativos usam a cor `#9B8AFB`; o miniplayer preserva seus controles e progresso.

### Shuffle e histórico

- Ativar ou desativar Shuffle preserva a música, a posição e o estado de reprodução, sem recarregar o áudio.
- Ao ativar, embaralha apenas as entradas ainda não visitadas no ciclo. Uma seleção inicial no meio da fila também permite visitar as músicas anteriores.
- Anterior percorre o histórico; Próxima refaz o percurso quando o usuário volta. O futuro já percorrido é preservado ao alternar Shuffle.
- Sem histórico, Anterior reinicia a faixa atual em Shuffle. No modo sequencial, mantém o comportamento anterior do aplicativo: seleciona a faixa precedente na fila original, quando existe.
- Ao desativar, depois de refazer eventual histórico futuro, segue a ordem original a partir da última entrada desse percurso.
- Com Repeat All, cada novo ciclo contém toda a fila e evita começar pela última faixa do ciclo anterior, quando há alternativa.
- Voltar manualmente ou alternar Shuffle pode repetir faixas intencionalmente. Sem essas ações, cada entrada é visitada uma vez por ciclo.
- Uma nova seleção explícita de biblioteca/playlist inicia outro percurso e preserva os modos escolhidos. Editar, ordenar ou excluir uma playlist não altera a fila ativa.

### Modos de repetição

O botão alterna entre **Off → All → One → Off**.

| Modo | Término automático | Próxima manual |
|---|---|---|
| Off | Avança; encerra na última faixa | Avança; sem ação no fim |
| All | Avança; inicia outro ciclo no fim | Avança; inicia outro ciclo no fim |
| One | Reinicia somente a música atual | Mesmo comportamento de Off |

Anterior sempre usa as regras de histórico descritas acima. Repeat One não bloqueia a navegação manual nem acrescenta repetições automáticas ao histórico.

- Filas vazias não carregam áudio; uma única faixa encerra em Off e repete em All/One.
- Trocar modos enquanto pausado não inicia a reprodução.
- Erros interrompem a reprodução e permitem tentar novamente ou avançar manualmente; não há tentativas automáticas infinitas.
- Interrupções e perda de foco continuam pausando sem retomada automática.
- Reinícios automáticos passam pelo carregamento protegido do controller; esta etapa não oferece repetição sem intervalo audível.
- Os modos duram enquanto o runtime existe, inclusive em segundo plano e ao trocar de telas. Após encerrar o processo, os padrões são Shuffle desligado e Repeat Off. Não há persistência de preferências nesta etapa.

### Integração Android e validação física

O `RikoAudioHandler` publica os modos em `PlaybackState` e aceita `setShuffleMode`/`setRepeatMode`, delegando ao controller. O valor externo `group` é normalizado para `all`, pois não há grupos de reprodução. A fila Android mantém a ordem original e `queueIndex` identifica a faixa atual nessa fila.

A presença de botões para esses modos depende do cliente Android. No Redmi 13C, validar:

- Notificação e tela de bloqueio: play/pause, anterior/próxima, metadados e atualização de faixa nos modos combinados.
- Shuffle + All por mais de um ciclo, incluindo uma fila com somente uma música.
- Repeat One ao terminar uma música e ao usar os botões manuais.
- Reprodução com tela apagada, aplicativo minimizado e após remoção da tarefa enquanto toca.
- Chamadas, outro aplicativo obtendo foco e desconexão de fone: pausa sem retomada inesperada.
- Arquivo removido/permissão revogada e comandos rápidos durante troca de faixa.
- Controles na tela completa e progresso do miniplayer com fontes ampliadas.

## Próximas funcionalidades

O desenvolvimento continuará com:

- Melhorias nas configurações do player.
- Refinamentos de desempenho e estabilidade.
- Reformulação da interface e melhorias de experiência do usuário.

## Status do projeto

**Em desenvolvimento.**

A biblioteca musical, a reprodução de áudio, a integração com os controles de mídia do Android e o gerenciamento de playlists locais estão implementados.

O projeto segue em desenvolvimento..
