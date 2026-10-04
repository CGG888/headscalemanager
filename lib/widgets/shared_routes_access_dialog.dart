import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/l10n/l10n.dart';

enum RouteAccessChoice { none, full, custom }

class SharedRoutesAccessDialog extends StatefulWidget {
  final Node destinationNode;

  const SharedRoutesAccessDialog({super.key, required this.destinationNode});

  @override
  State<SharedRoutesAccessDialog> createState() =>
      _SharedRoutesAccessDialogState();
}

class _SharedRoutesAccessDialogState extends State<SharedRoutesAccessDialog> {
  RouteAccessChoice _choice = RouteAccessChoice.none;
  final Map<String, _CustomRule> _customRules = {};
  late List<String> _lanRoutes;

  @override
  void initState() {
    super.initState();
    _lanRoutes = widget.destinationNode.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();
    for (var route in _lanRoutes) {
      _customRules[route] = _CustomRule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n(Localizations.localeOf(context));

    return AlertDialog(
      title: Text(l10n.t('Accès aux routes partagées', 'Shared Routes Access', '已共享路由访问')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Le nœud de destination partage les sous-réseaux suivants. Choisissez comment y accéder.', 'The destination node shares the following subnets. Choose how to access them.', '目标节点共享了以下子网。请选择访问它们的方式。'),
            ),
            const SizedBox(height: 16),
            ..._buildChoiceRadios(l10n),
            if (_choice == RouteAccessChoice.custom)
              _buildCustomRulesSection(l10n),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleConfirm,
          child: Text(l10n.t('Confirmer', 'Confirm', '确认')),
        ),
      ],
    );
  }

  List<Widget> _buildChoiceRadios(L10n l10n) {
    return [
      RadioGroup<RouteAccessChoice>(
        groupValue: _choice,
        onChanged: (value) => setState(() => _choice = value!),
        child: Column(
          children: [
            RadioListTile<RouteAccessChoice>(
              title:
                  Text(l10n.t('Accès au nœud uniquement', 'Node access only', '仅访问节点')),
              subtitle: Text(l10n.t('Autoriser l\'accès au nœud mais pas aux sous-réseaux partagés', 'Allow access to the node but not to shared subnets', '允许访问该节点，但不允许访问已共享子网')),
              value: RouteAccessChoice.none,
            ),
            RadioListTile<RouteAccessChoice>(
              title: Text(l10n.t('Accès total', 'Full access', '完全访问')),
              subtitle: Text(l10n.t('Autoriser l\'accès au nœud et à toutes les routes partagées', 'Allow access to the node and all shared routes', '允许访问该节点及所有已共享路由')),
              value: RouteAccessChoice.full,
            ),
            RadioListTile<RouteAccessChoice>(
              title: Text(l10n.t('Accès personnalisé', 'Custom access', '自定义访问')),
              subtitle: Text(l10n.t('Définir des règles spécifiques par sous-réseau', 'Define specific rules per subnet', '为每个子网定义特定规则')),
              value: RouteAccessChoice.custom,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildCustomRulesSection(L10n l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _lanRoutes.map((route) {
          return _SubnetRuleCard(
            subnet: route,
            rule: _customRules[route]!,
            l10n: l10n,
          );
        }).toList(),
      ),
    );
  }

  void _handleConfirm() {
    final l10n = L10n(Localizations.localeOf(context));

    // Debug: Afficher le choix sélectionné
    debugPrint('DEBUG DIALOG: Choix sélectionné: $_choice');

    if (_choice == RouteAccessChoice.custom) {
      // Validate all custom rules before popping
      for (var route in _lanRoutes) {
        final rule = _customRules[route]!;
        final startIp = rule.startIpController.text;
        final endIp = rule.endIpController.text;

        if (startIp.isNotEmpty && !IpUtils.isValidIp(startIp)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${l10n.t('Format IP de début invalide pour', 'Invalid start IP format for', '起始 IP 格式无效：')} $route')));
          return;
        }

        if (startIp.isNotEmpty && !IpUtils.isIpInSubnet(startIp, route)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${l10n.t('IP de début n\'est pas dans le sous-réseau', 'Start IP is not in subnet', '起始 IP 不在子网内')} $route')));
          return;
        }

        if (endIp.isNotEmpty && !IpUtils.isValidIp(endIp)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${l10n.t('Format IP de fin invalide pour', 'Invalid end IP format for', '结束 IP 格式无效：')} $route')));
          return;
        }

        if (endIp.isNotEmpty && !IpUtils.isIpInSubnet(endIp, route)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${l10n.t('IP de fin n\'est pas dans le sous-réseau', 'End IP is not in subnet', '结束 IP 不在子网内')} $route')));
          return;
        }
      }
    }

    final result = {
      'choice': _choice,
      'rules': _customRules.map((key, value) => MapEntry(key, {
            'startIp': value.startIpController.text,
            'endIp': value.endIpController.text,
            'ports': value.portsController.text,
          })),
    };

    // Debug: Afficher le résultat qui va être retourné
    debugPrint('DEBUG DIALOG: Résultat retourné: $result');

    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    for (var rule in _customRules.values) {
      rule.dispose();
    }
    super.dispose();
  }
}

class _SubnetRuleCard extends StatelessWidget {
  final String subnet;
  final _CustomRule rule;
  final L10n l10n;

  const _SubnetRuleCard(
      {required this.subnet, required this.rule, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subnet, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: rule.startIpController,
              decoration: InputDecoration(
                labelText: l10n.t('IP de début', 'Start IP', '起始 IP'),
                hintText: context.l10n.t('Ex: 192.168.1.10', 'e.g. 192.168.1.10', '例如：192.168.1.10'),
              ),
            ),
            TextFormField(
              controller: rule.endIpController,
              decoration: InputDecoration(
                labelText: l10n.t('IP de fin (optionnel)', 'End IP (optional)', '结束 IP（选填）'),
                hintText: l10n.t('Laisser vide si IP unique', 'Leave empty for single IP', '单一 IP 时留空'),
              ),
            ),
            TextFormField(
              controller: rule.portsController,
              decoration: InputDecoration(
                labelText: l10n.t('Ports (optionnel)', 'Ports (optional)', '端口（选填）'),
                hintText:
                    l10n.t('Ex: 80, 443, 1024-2048', 'E.g. 80, 443, 1024-2048', '例如：80, 443, 1024-2048'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRule {
  final TextEditingController startIpController = TextEditingController();
  final TextEditingController endIpController = TextEditingController();
  final TextEditingController portsController = TextEditingController();

  void dispose() {
    startIpController.dispose();
    endIpController.dispose();
    portsController.dispose();
  }
}
