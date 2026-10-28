# Riko Player

Aplicativo de reprodução de músicas locais para Android, desenvolvido com Flutter e Dart.

## Sobre o projeto

O Riko Player é um projeto pessoal que tem como objetivo oferecer uma experiência simples, moderna e intuitiva para ouvir músicas armazenadas localmente em dispositivos Android.

O aplicativo está sendo desenvolvido com foco em uma interface organizada, navegação intuitiva, desempenho e facilidade de uso.

## Tecnologias utilizadas

- Flutter
- Dart
- Material Design 3
- Android MediaStore (por meio do `device_audio_query`)

## Funcionalidades implementadas

### Interface e navegação

- Tema escuro com identidade visual própria.
- Navegação entre Biblioteca e Playlists.
- Tela de Configurações.
- Interface adaptada para dispositivos Android.

### Biblioteca de músicas

- Leitura automática das músicas armazenadas no dispositivo.
- Exibição de título, artista e duração.
- Exibição das capas dos álbuns, quando disponíveis.
- Ícone padrão para músicas sem capa.
- Pesquisa por título e artista.
- Atualização manual e automática da biblioteca.
- Tratamento de permissões, carregamento e erros.

### Desempenho

- Construção sob demanda dos itens da biblioteca utilizando `SliverList.builder`.
- Carregamento de capas conforme os itens são exibidos.
- Cache LRU de capas com limites de memória.
- Reaproveitamento de consultas de capas em andamento.
- Atualização da biblioteca sem interromper a exibição da lista.
- Preservação do estado dos itens durante pesquisas.

## Pré-requisitos

- Flutter SDK
- Android SDK
- Android Studio ou VS Code
- Dispositivo Android ou emulador configurado

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

## Testes

Para executar os testes automatizados:

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

## Status do projeto

Em desenvolvimento.

A estrutura inicial, a navegação e a biblioteca de músicas locais estão implementadas, incluindo pesquisa, carregamento de capas e otimizações de desempenho.

A reprodução musical, os controles de áudio e o gerenciamento de playlists ainda serão desenvolvidos.