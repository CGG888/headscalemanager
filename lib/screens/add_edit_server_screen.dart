import 'package:flutter/material.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class AddEditServerScreen extends StatefulWidget {
  final Server? server;

  const AddEditServerScreen({super.key, this.server});

  @override
  State<AddEditServerScreen> createState() => _AddEditServerScreenState();
}

class _AddEditServerScreenState extends State<AddEditServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _urlController = TextEditingController(text: widget.server?.url ?? '');
    _apiKeyController =
        TextEditingController(text: widget.server?.apiKey ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n(context.watch<AppProvider>().locale);
    final isEditing = widget.server != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (l10n.t('Modifier le serveur', 'Edit Server', '编辑服务器'))
              : (l10n.t('Ajouter un serveur', 'Add Server', '添加服务器')),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.t('Nom du serveur', 'Server Name', '服务器名称'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.t('Veuillez entrer un nom', 'Please enter a name', '请输入名称');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.t('URL du serveur', 'Server URL', '服务器 URL'),
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      !Uri.parse(value).isAbsolute) {
                    return l10n.t('Veuillez entrer une URL valide', 'Please enter a valid URL', '请输入有效的 URL');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: l10n.t('Clé API', 'API Key', 'API 密钥'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.t('Veuillez entrer une clé API', 'Please enter an API key', '请输入 API 密钥');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveServer,
                child: Text(l10n.t('Enregistrer', 'Save', '保存')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveServer() {
    if (_formKey.currentState!.validate()) {
      final appProvider = context.read<AppProvider>();
      final name = _nameController.text.trim();
      final url = _urlController.text.trim();
      final apiKey = _apiKeyController.text.trim();

      if (widget.server == null) {
        final newServer = Server(name: name, url: url, apiKey: apiKey);
        appProvider.addServer(newServer);
      } else {
        final updatedServer = Server(
          id: widget.server!.id,
          name: name,
          url: url,
          apiKey: apiKey,
        );
        appProvider.updateServer(updatedServer);
      }
      Navigator.of(context).pop();
    }
  }
}
