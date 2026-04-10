import 'package:flutter/material.dart';
import 'vorrat_page.dart';
import 'food_item.dart';

void main() => runApp(const FoodSaverApp());

class FoodSaverApp extends StatelessWidget {
  const FoodSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _highlightNotifier = ValueNotifier<FoodItem?>(null);

  void _navigateToVorrat(FoodItem item) {
    _highlightNotifier.value = item;
    setState(() => _selectedIndex = 1);
  }

  @override
  void dispose() {
    _highlightNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onItemTap: _navigateToVorrat),
      VorratPage(highlightNotifier: _highlightNotifier),
      const Scaffold(body: Center(child: Text('Rezepte – coming soon'))),
      const Scaffold(body: Center(child: Text('Statistik – coming soon'))),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Vorrat'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Rezepte'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Statistik'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onItemTap});

  final void Function(FoodItem)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodRescue AI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.person_outline)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- IMPACT CARD ---
            _buildImpactCard(),
            const SizedBox(height: 24),

            // --- SCAN BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {}, // Hier Kamera-Logik starten
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("NEUES LEBENSMITTEL SCANNEN", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- REZEPT VORSCHLÄGE ---
            const Text("KI-Rezeptvorschläge für dich", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildRecipeList(),
            
            const SizedBox(height: 32),

            // --- KRITISCHE LEBENSMITTEL ---
            const Text("Läuft bald ab", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildExpiringItems(onItemTap),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Dein Impact diesen Monat", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _impactStat("42,50 €", "Gespart", Icons.euro_symbol),
              _impactStat("12,4 kg", "CO₂ gespart", Icons.cloud_done_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecipeList() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Container(decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))))),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("KI-Rezept ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpiringItems(void Function(FoodItem)? onItemTap) {
    final items = (FoodStore.items.toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate)))
        .take(3)
        .toList();

    if (items.isEmpty) {
      return const Text('Keine Lebensmittel im Vorrat.',
          style: TextStyle(color: Colors.black45));
    }

    return Column(
      children: items.map((item) {
        final (color, label) = switch (item.status) {
          ExpiryStatus.expired => (Colors.red.shade700, 'Abgelaufen'),
          ExpiryStatus.today => (Colors.red.shade500, 'Heute fällig'),
          ExpiryStatus.soon =>
            (Colors.orange.shade700, 'Noch ${item.daysLeft} Tag(e)'),
          ExpiryStatus.ok =>
            (Colors.green.shade700, 'Noch ${item.daysLeft} Tage'),
        };
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.fastfood)),
          title: Text(item.name),
          subtitle: Text(label, style: TextStyle(color: color)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onItemTap?.call(item),
        );
      }).toList(),
    );
  }
}