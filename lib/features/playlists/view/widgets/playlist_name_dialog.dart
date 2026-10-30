import 'package:flutter/material.dart';

import '../../models/playlist.dart';

Future<String?> showPlaylistNameDialog(BuildContext context, {String? name}) =>
    showDialog<String>(
      context: context,
      builder: (_) => PlaylistNameDialog(name: name),
    );

Future<bool> confirmPlaylistDeletion(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir playlist?'),
        content: Text(
          'Excluir "$name"? Os arquivos de áudio não serão excluídos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    ) ??
    false;

class PlaylistNameDialog extends StatefulWidget {
  const PlaylistNameDialog({super.key, this.name});
  final String? name;
  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  late final TextEditingController _name;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.pop(context, validatePlaylistName(_name.text));
    } on PlaylistException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name == null ? 'Nova playlist' : 'Renomear playlist'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 100,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Nome da playlist',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Salvar')),
    ],
  );
}
