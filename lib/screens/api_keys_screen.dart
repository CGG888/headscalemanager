import 'package:flutter/material.dart';
import 'package:headscalemanager/models/api_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  late Future<List<ApiKey>> _apiKeysFuture;

  @override
  void initState() {
    super.initState();
    _refreshApiKeys();
  }

  void _refreshApiKeys() {
    if (!mounted) return;
    setState(() {
      _apiKeysFuture = context.read<AppProvider>().apiService.listApiKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('Clés API', 'API Keys'),
            style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: FutureBuilder<List<ApiKey>>(
        future: _apiKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('${l10n.t('Erreur', 'Error')}: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(
                    l10n.t('Aucune clé API trouvée.', 'No API key found.')));
          }

          final apiKeys = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: apiKeys.length,
            itemBuilder: (context, index) {
              final apiKey = apiKeys[index];
              return _ApiKeyCard(
                  key: ValueKey(apiKey.prefix),
                  apiKey: apiKey,
                  onAction: _refreshApiKeys);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewApiKey,
        tooltip: l10n.t('Créer une clé API', 'Create API Key'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }

  Future<void> _createNewApiKey() async {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    // Calculer la date d'expiration à 6 mois à partir de maintenant
    final expirationDate =
        DateTime.now().add(const Duration(days: 182)); // Environ 6 mois

    final newApiKey = await context
        .read<AppProvider>()
        .apiService
        .createApiKey(expiration: expirationDate);
    _refreshApiKeys();
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.t('Nouvelle clé API créée', 'New API Key Created')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('Veuillez copier cette clé maintenant. Vous ne pourrez pas la voir à nouveau.', 'Please copy this key now. You will not be able to see it again.')),
              const SizedBox(height: 16),
              SelectableText(newApiKey,
                  style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.t('OK', 'OK')),
            ),
          ],
        ),
      );
    }
  }
}

class _ApiKeyCard extends StatelessWidget {
  final ApiKey apiKey;
  final VoidCallback onAction;

  const _ApiKeyCard({super.key, required this.apiKey, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text('Prefix: ${apiKey.prefix}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${apiKey.id}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
                '${l10n.t('Expiration', 'Expiration')}: ${apiKey.expiration?.toLocal() ?? (l10n.t('Jamais', 'Never'))}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
                '${l10n.t('Dernière utilisation', 'Last Seen')}: ${apiKey.lastSeen?.toLocal() ?? (l10n.t('Jamais', 'Never'))}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'expire',
              child: ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: Text(l10n.t('Faire expirer', 'Expire'))),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                  leading: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(l10n.t('Supprimer', 'Delete'))),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) async {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    final apiService = context.read<AppProvider>().apiService;

    switch (value) {
      case 'expire':
        final confirm = await _showConfirmationDialog(
            context,
            l10n.t('Faire expirer la clé API ?', 'Expire API Key?'),
            l10n.t('Voulez-vous vraiment faire expirer la clé API avec le préfixe ${apiKey.prefix} ?', 'Do you really want to expire the API key with prefix ${apiKey.prefix}?'));
        if (!context.mounted) return;
        if (confirm) {
          await apiService.expireApiKey(apiKey.prefix);
          if (context.mounted) onAction();
        }
        break;
      case 'delete':
        final confirm = await _showConfirmationDialog(
            context,
            l10n.t('Supprimer la clé API ?', 'Delete API Key?'),
            l10n.t('Voulez-vous vraiment supprimer la clé API avec le préfixe ${apiKey.prefix} ?', 'Do you really want to delete the API key with prefix ${apiKey.prefix}?'));
        if (!context.mounted) return;
        if (confirm) {
          await apiService.deleteApiKey(apiKey.prefix);
          if (context.mounted) onAction();
        }
        break;
    }
  }

  Future<bool> _showConfirmationDialog(
      BuildContext context, String title, String content) async {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
            content:
                Text(content, style: Theme.of(context).textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.t('Annuler', 'Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.t('Confirmer', 'Confirm'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
