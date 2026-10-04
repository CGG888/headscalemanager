import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/widgets/numpad_widget.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _securityService = SecurityService();

  String _enteredPin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _message = ''; // Will be set in didChangeDependencies

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial message here to access context
    final l10n = L10n(context.watch<AppProvider>().locale);
    setState(() {
      _message = l10n.t('Créez votre code PIN', 'Create your PIN');
    });
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), _submitPin);
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _submitPin() async {
    final l10n = L10n(context.read<AppProvider>().locale);
    if (!_isConfirming) {
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _isConfirming = true;
        _message = l10n.t('Confirmez votre code PIN', 'Confirm your PIN');
      });
    } else {
      if (_firstPin == _enteredPin) {
        await _securityService.savePin(_enteredPin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('Code PIN enregistré avec succès !', 'PIN saved successfully!')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _enteredPin = '';
          _firstPin = '';
          _isConfirming = false;
          _message = l10n.t('Les codes ne correspondent pas. Réessayez.', 'PINs do not match. Try again.');
        });
      }
    }
  }

  void _clearPin() async {
    final l10n = L10n(context.read<AppProvider>().locale);
    await _securityService.clearPin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('Code PIN supprimé.', 'PIN deleted.')),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n(context.watch<AppProvider>().locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Configurer le code PIN', 'Set up PIN Code')),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          TextButton(
            onPressed: _clearPin,
            child: Text(l10n.t('Supprimer', 'Delete'),
                style:
                    TextStyle(color: theme.appBarTheme.titleTextStyle?.color)),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(_message, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _enteredPin.length
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
              );
            }),
          ),
          const Spacer(),
          NumpadWidget(
            onNumberPressed: _onNumberPressed,
            onDeletePressed: _onDeletePressed,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
