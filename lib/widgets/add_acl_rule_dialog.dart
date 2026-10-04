import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/widgets/shared_routes_access_dialog.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class AddAclRuleDialog extends StatefulWidget {
  final List<Node> allNodes;

  const AddAclRuleDialog({
    super.key,
    required this.allNodes,
  });

  @override
  State<AddAclRuleDialog> createState() => _AddAclRuleDialogState();
}

class _AddAclRuleDialogState extends State<AddAclRuleDialog> {
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final _portController = TextEditingController();
  List<Node> _destinationNodes = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _destinationNodes = List.from(widget.allNodes);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Ajouter une règle ACL', 'Add ACL Rule', '添加 ACL 规则')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('Créez une exception pour autoriser la communication entre les appareils.', 'Create an exception to allow communication between devices.', '创建例外以允许设备之间通信。'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildNodeDropdown(
                l10n.t('Source (Nœud)', 'Source (Node)', '源（节点）'),
                _selectedSourceNode,
                widget.allNodes,
                (node) {
                  setState(() {
                    _selectedSourceNode = node;
                    _selectedDestinationNode = null;
                    if (node != null) {
                      _destinationNodes = widget.allNodes
                          .where((n) => n.id != node.id)
                          .toList();
                    } else {
                      _destinationNodes = List.from(widget.allNodes);
                    }
                  });
                },
                l10n.t('Veuillez sélectionner un nœud source', 'Please select a source node', '请选择源节点'),
              ),
              const SizedBox(height: 16),
              _buildNodeDropdown(
                l10n.t('Destination (Nœud)', 'Destination (Node)', '目标（节点）'),
                _selectedDestinationNode,
                _destinationNodes,
                (node) => setState(() => _selectedDestinationNode = node),
                l10n.t('Veuillez sélectionner un nœud destination', 'Please select a destination node', '请选择目标节点'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration(
                    l10n.t('Port(s)', 'Port(s)', '端口'), 'ex: 443, 8080-8089, *'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
        ),
        ElevatedButton(
          onPressed: _addRule,
          child: Text(l10n.t('Ajouter', 'Add', '添加')),
        ),
      ],
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(
    String label,
    Node? selectedNode,
    List<Node> nodes,
    ValueChanged<Node?> onChanged,
    String? validationMessage,
  ) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return DropdownButtonFormField<Node>(
      initialValue: selectedNode,
      decoration: _buildInputDecoration(
          label, l10n.t('Choisir un nœud', 'Choose a node', '选择节点')),
      items: nodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
      validator: (value) {
        if (value == null) {
          return validationMessage;
        }
        return null;
      },
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    if (_selectedSourceNode!.ipAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('Le nœud source doit avoir au moins une adresse IP.', 'Source node must have at least one IP address.', '源节点必须至少有一个 IP 地址。')),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    final sourceIp = _selectedSourceNode!.ipAddresses.first;

    List<Map<String, dynamic>> newRulesToAdd = [];

    final sharedLanRoutes = _selectedDestinationNode!.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();

    if (sharedLanRoutes.isNotEmpty) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SharedRoutesAccessDialog(
          destinationNode: _selectedDestinationNode!,
        ),
      );

      if (result == null) return;

      final choice = result['choice'] as RouteAccessChoice;
      final rules = result['rules'] as Map<String, dynamic>;

      if (choice == RouteAccessChoice.none) {
        // Fallback: add rule for the node itself if subnet access is denied
        if (_selectedDestinationNode!.ipAddresses.isNotEmpty) {
          final destinationIp = _selectedDestinationNode!.ipAddresses.first;
          final port = _portController.text.trim();
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': destinationIp,
            'port': port.isEmpty ? '*' : port,
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('Accès au sous-réseau non configuré et le nœud n\'a pas d\'IP pour une règle de base.', 'Subnet access not configured and the node has no IP for a fallback rule.', '未配置子网访问，且节点没有 IP 可用于兜底规则。')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
          return;
        }
      }

      if (choice == RouteAccessChoice.full) {
        for (var route in sharedLanRoutes) {
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': route,
            'port': '*',
          });
        }
      } else if (choice == RouteAccessChoice.custom) {
        rules.forEach((route, ruleDetails) {
          final startIp = (ruleDetails['startIp'] as String).trim();
          final endIp = (ruleDetails['endIp'] as String).trim();
          final ports = (ruleDetails['ports'] as String).trim();

          if (startIp.isEmpty) return;

          String dst;
          if (endIp.isNotEmpty) {
            final range = IpUtils.generateIpRange(startIp, endIp);
            dst = range.join(',');
          } else {
            dst = startIp;
          }

          if (dst.isNotEmpty) {
            newRulesToAdd.add({
              'src': sourceIp,
              'dst': dst,
              'port': ports.isEmpty ? '*' : ports,
            });
          }
        });
      }
    } else {
      if (_selectedDestinationNode!.ipAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('Le nœud destination doit avoir au moins une adresse IP.', 'Destination node must have at least one IP address.', '目标节点必须至少有一个 IP 地址。')),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      final destinationIp = _selectedDestinationNode!.ipAddresses.first;

      final port = _portController.text.trim();
      newRulesToAdd.add({
        'src': sourceIp,
        'dst': destinationIp,
        'port': port.isEmpty ? '*' : port,
      });
    }

    if (mounted) {
      Navigator.of(context).pop(newRulesToAdd);
    }
  }
}
