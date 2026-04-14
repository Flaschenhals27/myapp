import 'package:flutter/material.dart';
import 'food_item.dart';
import 'recipe_service.dart';

class RezeptePage extends StatefulWidget {
  const RezeptePage({super.key});

  @override
  State<RezeptePage> createState() => _RezeptePageState();
}

class _RezeptePageState extends State<RezeptePage> {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  List<FoodItem> get _expiringItems {
    return (FoodStore.items.toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate)))
        .where((i) =>
            i.status == ExpiryStatus.expired ||
            i.status == ExpiryStatus.today ||
            i.status == ExpiryStatus.soon)
        .toList();
  }

  Future<void> _generateRecipes() async {
    final expiring = _expiringItems;
    if (expiring.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipes = await RecipeService.fetchRecipes(expiring);
      setState(() => _recipes = recipes);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('kein_api_key') || msg.contains('ungültiger_api_key')) {
        if (mounted) await _showApiKeyDialog();
      } else {
        setState(() => _error = 'Fehler beim Laden der Rezepte.\n$msg');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController();
    final existing = await RecipeService.getApiKey();
    if (existing != null) ctrl.text = existing;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Groq API-Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gib deinen Groq API-Key ein, um KI-Rezeptvorschläge zu nutzen.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'gsk_...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await RecipeService.saveApiKey(ctrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiring = _expiringItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezeptvorschläge',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: 'API-Key ändern',
            onPressed: () => _showApiKeyDialog(),
          ),
        ],
      ),
      body: expiring.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExpiringChips(expiring),
                  const SizedBox(height: 20),
                  _buildGenerateButton(expiring),
                  const SizedBox(height: 24),
                  if (_isLoading) _buildLoadingState(),
                  if (_error != null) _buildErrorCard(),
                  if (_recipes.isNotEmpty && !_isLoading) ...[
                    const Text('Vorgeschlagene Rezepte',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._recipes.map(_buildRecipeCard),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              'Kein Lebensmittel läuft bald ab!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Wenn Produkte in den nächsten 3 Tagen ablaufen, bekommst du hier Rezeptideen.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringChips(List<FoodItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bald ablaufende Zutaten:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: items.map((item) {
            final color = switch (item.status) {
              ExpiryStatus.expired => Colors.red.shade700,
              ExpiryStatus.today => Colors.red.shade500,
              ExpiryStatus.soon => Colors.orange.shade700,
              ExpiryStatus.ok => Colors.green.shade700,
            };
            final label = switch (item.status) {
              ExpiryStatus.expired => 'abgelaufen',
              ExpiryStatus.today => 'heute',
              _ => '${item.daysLeft}T',
            };
            return Chip(
              avatar: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              ),
              label: Text(item.name),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              backgroundColor: color.withValues(alpha: 0.06),
              padding: EdgeInsets.zero,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(List<FoodItem> items) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _generateRecipes,
        icon: const Icon(Icons.auto_awesome),
        label: Text(
          _recipes.isEmpty
              ? 'KI-Rezepte generieren (${items.length} Zutaten)'
              : 'Neue Vorschläge generieren',
          style: const TextStyle(fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Rezepte werden generiert...',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.restaurant_menu, color: Colors.green.shade700),
        ),
        title: Text(recipe.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('${recipe.durationMinutes} Min.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        children: [
          Text(recipe.description,
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          _buildSection('Zutaten', Icons.shopping_basket_outlined,
              recipe.ingredients.map((i) => '• $i').toList()),
          const SizedBox(height: 12),
          _buildSection('Zubereitung', Icons.list_outlined,
              recipe.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').toList()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.green.shade800)),
        ]),
        const SizedBox(height: 6),
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l, style: const TextStyle(height: 1.4)),
            )),
      ],
    );
  }
}
