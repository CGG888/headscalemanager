import 'package:flutter/material.dart';
import 'package:headscalemanager/models/client_command.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class CommandFiltersSection extends StatelessWidget {
  final L10n l10n;
  final TextEditingController searchController;
  final String selectedPlatform;
  final CommandCategory? selectedCategory;
  final bool showOnlyElevated;
  final List<CommandCategory> categories;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<CommandCategory?> onCategoryChanged;
  final ValueChanged<bool?> onElevationChanged;
  final VoidCallback onSearchClear;

  const CommandFiltersSection({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.selectedPlatform,
    required this.selectedCategory,
    required this.showOnlyElevated,
    required this.categories,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onElevationChanged,
    required this.onSearchClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText:
                  l10n.t('Rechercher une commande...', 'Search command...', '搜索命令……'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onSearchClear,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          const SizedBox(height: 12),

          // Filtres
          Row(
            children: [
              // Sélecteur de plateforme
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPlatform,
                  decoration: InputDecoration(
                    labelText: l10n.t('Plateforme', 'Platform', '平台'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  items: ['Windows', 'Linux'].map((platform) {
                    return DropdownMenuItem(
                      value: platform,
                      child: Row(
                        children: [
                          Icon(
                            platform == 'Windows'
                                ? Icons.computer
                                : Icons.terminal,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(platform),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: onPlatformChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Sélecteur de catégorie
              Expanded(
                child: DropdownButtonFormField<CommandCategory?>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: l10n.t('Catégorie', 'Category', '类别'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  items: [
                    DropdownMenuItem<CommandCategory?>(
                      value: null,
                      child: Text(l10n.t('Toutes', 'All', '全部')),
                    ),
                    ...categories.map((category) {
                      return DropdownMenuItem<CommandCategory?>(
                        value: category,
                        child: Text(category.label(l10n)),
                      );
                    }),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filtre élévation
          CheckboxListTile(
            title: Text(
              l10n.t('Commandes privilégiées uniquement', 'Elevated commands only', '仅显示提权命令'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              l10n.t('Nécessitent des droits administrateur', 'Require administrator rights', '需要管理员权限'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: showOnlyElevated,
            onChanged: onElevationChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
