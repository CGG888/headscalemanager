import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart'; // For showSafeSnackBar
import 'package:headscalemanager/l10n/l10n.dart';

/// Dialogue pour afficher une commande CLI générée et permettre de la copier.
///
/// Ce dialogue est utilisé pour présenter à l'utilisateur une commande à exécuter
/// manuellement (par exemple, sur un serveur Headscale) et offre une option
/// pour copier cette commande dans le presse-papiers.
class CliCommandDisplayDialog extends StatelessWidget {
  /// La commande CLI à afficher.
  final String command;

  const CliCommandDisplayDialog({super.key, required this.command});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return AlertDialog(
      title: Text(l10n.t('Commande CLI', 'CLI Command', 'CLI 命令')),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(l10n.t('Veuillez copier cette commande et l\'exécuter dans votre terminal où la CLI `headscale` est configurée.', 'Please copy this command and run it in your terminal where the `headscale` CLI is configured.', '请复制此命令，并在已配置 `headscale` CLI 的终端中运行。')),
            const SizedBox(height: 16),
            // Diagnostic: Wrap SelectableText in a SizedBox with fixed dimensions
            SizedBox(
              width: 250, // Fixed width for testing
              height: 100, // Fixed height for testing
              child: SelectableText(
                command,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.t('Fermer', 'Close', '关闭')),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(l10n.t('Copier la commande CLI', 'Copy CLI Command', '复制 CLI 命令')),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: command));
            if (!context.mounted) return;
            showSafeSnackBar(
                context,
                l10n.t('Commande copiée dans le presse-papiers !', 'Command copied to clipboard!', '命令已复制到剪贴板！'));
            Navigator.of(context).pop(); // Ferme le dialogue après copie
          },
        ),
      ],
    );
  }
}
