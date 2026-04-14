import 'package:flutter/material.dart';
import 'food_item.dart';

class VorratPage extends StatefulWidget {
  const VorratPage({super.key, this.highlightNotifier});

  final ValueNotifier<FoodItem?>? highlightNotifier;

  @override
  State<VorratPage> createState() => _VorratPageState();
}

class _VorratPageState extends State<VorratPage> {
  String _searchQuery = '';
  String? _selectedCategory;
  FoodItem? _highlightedItem;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.highlightNotifier?.addListener(_onHighlight);
  }

  @override
  void dispose() {
    widget.highlightNotifier?.removeListener(_onHighlight);
    _scrollController.dispose();
    super.dispose();
  }

  void _onHighlight() {
    final item = widget.highlightNotifier?.value;
    if (item == null) return;
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _highlightedItem = item;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _sortedItems.indexOf(item);
      if (index >= 0) {
        const itemHeight = 88.0;
        _scrollController.animateTo(
          index * itemHeight,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      // Highlight nach kurzer Zeit wieder entfernen
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedItem = null);
      });
    });
  }

  List<FoodItem> get _sortedItems => FoodStore.items.toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  List<FoodItem> get _filtered {
    return _sortedItems.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> get _categories {
    return FoodStore.items.map((e) => e.category).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Vorrat',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Filter zurücksetzen',
              onPressed: () => setState(() => _selectedCategory = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Lebensmittel suchen...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          _buildCategoryChips(),
          _buildSummaryRow(items),
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _buildFoodCard(context, items[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Manuell hinzufügen'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _categories.map((cat) {
          final selected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(cat),
              selected: selected,
              onSelected: (_) => setState(() {
                _selectedCategory = selected ? null : cat;
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryRow(List<FoodItem> items) {
    final expiredCount =
        items.where((i) => i.status == ExpiryStatus.expired).length;
    final soonCount = items
        .where((i) =>
            i.status == ExpiryStatus.today || i.status == ExpiryStatus.soon)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text('${items.length} Artikel',
              style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          if (expiredCount > 0) ...[
            Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.red.shade700),
            const SizedBox(width: 4),
            Text('$expiredCount abgelaufen',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
          ],
          if (soonCount > 0) ...[
            Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text('$soonCount bald fällig',
                style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, FoodItem item) {
    final (color, label) = switch (item.status) {
      ExpiryStatus.expired => (Colors.red.shade700, 'Abgelaufen'),
      ExpiryStatus.today => (Colors.red.shade500, 'Heute fällig'),
      ExpiryStatus.soon =>
        (Colors.orange.shade700, 'Noch ${item.daysLeft} Tag(e)'),
      ExpiryStatus.ok => (Colors.green.shade700, 'Noch ${item.daysLeft} Tage'),
    };

    final isHighlighted = item == _highlightedItem;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isHighlighted
            ? [BoxShadow(color: Colors.green.shade300, blurRadius: 12, spreadRadius: 2)]
            : [],
      ),
      child: Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isHighlighted ? Colors.green.shade50 : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_categoryIcon(item.category), color: color),
        ),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(item.category,
            style: const TextStyle(color: Colors.black54)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.expiryDate.day.toString().padLeft(2, '0')}.${item.expiryDate.month.toString().padLeft(2, '0')}.${item.expiryDate.year}',
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
        onTap: () => _showItemActions(context, item),
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.kitchen_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Keine Treffer'
                : 'Noch keine Lebensmittel',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          if (_searchQuery.isEmpty && _selectedCategory == null) ...[
            const SizedBox(height: 8),
            Text('Scanne ein Produkt oder füge es manuell hinzu.',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ],
      ),
    );
  }

  void _showItemActions(BuildContext context, FoodItem item) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(item.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, item);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Löschen',
                  style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(context);
                setState(() => FoodStore.items.remove(item));
                FoodStore.save();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, FoodItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final catCtrl = TextEditingController(text: item.category);
    DateTime selectedDate = item.expiryDate;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Eintrag bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kategorie'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('MHD: ',
                      style: TextStyle(color: Colors.black54)),
                  TextButton(
                    child: Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 30)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setLocalState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  final index = FoodStore.items.indexOf(item);
                  if (index != -1) {
                    FoodStore.items[index] = FoodItem(
                      name: nameCtrl.text.trim(),
                      category: catCtrl.text.trim().isEmpty
                          ? 'Sonstiges'
                          : catCtrl.text.trim(),
                      expiryDate: selectedDate,
                      barcode: item.barcode,
                    );
                  }
                });
                FoodStore.save();
                Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Lebensmittel hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                    labelText: 'Kategorie (z.B. Gemüse)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('MHD: ',
                      style: TextStyle(color: Colors.black54)),
                  TextButton(
                    child: Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 30)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setLocalState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  FoodStore.items.add(FoodItem(
                    name: nameCtrl.text.trim(),
                    category: catCtrl.text.trim().isEmpty
                        ? 'Sonstiges'
                        : catCtrl.text.trim(),
                    expiryDate: selectedDate,
                  ));
                });
                FoodStore.save();
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'milchprodukte' => Icons.water_drop_outlined,
      'gemüse' => Icons.eco_outlined,
      'obst' => Icons.apple,
      'backwaren' => Icons.breakfast_dining,
      'fleisch' => Icons.set_meal,
      'getränke' => Icons.local_drink_outlined,
      'tiefkühl' => Icons.ac_unit,
      _ => Icons.fastfood_outlined,
    };
  }
}
