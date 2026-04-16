import 'package:flutter/material.dart';
import 'vorrat_page.dart';
import 'food_item.dart';
import 'rezepte_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scanner_page.dart';


// --- NEUE FARBPALETTE FÜR DEN LOOK ---
class AppColors {
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF66BB6A);
  static const Color bg = Color(0xFFF8FAF7); // Sehr helles, frisches Grün-Grau
  static const Color cardShadow = Color(0x1A000000);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FoodStore.load();
  runApp(const FoodSaverApp());
}

class FoodSaverApp extends StatelessWidget {
  const FoodSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: AppColors.bg,
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
      const RezeptePage(),
      const Scaffold(body: Center(child: Text('Statistik – coming soon'))),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10)],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accentGreen.withOpacity(0.2),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Vorrat'),
            NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Rezepte'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Statistik'),
          ],
        ),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent, 
        elevation: 0,
        centerTitle: false, 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.quicksand(
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
                children: const [
                  TextSpan(
                    text: 'Green',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  TextSpan(
                    text: 'Spoon',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF66BB6A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2), 
              height: 4,
              width: 100, 
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.4), 
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: SquigglePainter(),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.account_circle_outlined, 
                size: 30, 
                color: Color(0xFF1B5E20)
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImpactCard(),
            const SizedBox(height: 24),
            
            // --- DER NEUE, KLICKBARE SCANNER BUTTON ---
            
            _buildActionCard(
              title: "Lebensmittel scannen",
              subtitle: "MHD & Name automatisch erkennen",
              icon: Icons.qr_code_scanner_rounded,
              onTap: () async {
                // 1. Scanner aufrufen und auf die Liste warten
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerPage()),
                );

                // 2. Prüfen, ob wir die Liste bekommen haben (Haken wurde geklickt)
                // Wir prüfen explizit auf List<ScannedProduct>
                if (result != null && result is List<ScannedProduct>) {
                  if (result.isEmpty) return; // Nichts gescannt, nichts zu tun

                  // 3. Jedes gescannte Produkt in die Vorrats-Datenbank übersetzen
                  for (final scannedItem in result) {
                    
                    // Da wir Mengen zählen (z.B. x3), fügen wir es entsprechend oft hinzu
                    for (int i = 0; i < scannedItem.quantity; i++) {
                      FoodStore.items.add(
                        FoodItem(
                          name: scannedItem.name,
                          category: 'Neu gescannt', // Eine Standard-Kategorie
                          // Das echte MHD kommt später, wir setzen erst mal +7 Tage als Standard
                          expiryDate: DateTime.now().add(const Duration(days: 7)), 
                        )
                      );
                    }
                  }

                  // 4. Den neuen Vorrat dauerhaft speichern
                  FoodStore.save();

                  // 5. Erfolgsmeldung anzeigen
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${result.length} Produkt(e) erfolgreich gespeichert!'),
                      backgroundColor: const Color(0xFF66BB6A),
                    ),
                  );
                }
              },
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle("KI-Rezeptvorschläge", Icons.auto_awesome_outlined),
            const SizedBox(height: 16),
            _buildRecipeList(),
            
            const SizedBox(height: 32),
            _buildSectionTitle("Dringend verbrauchen", Icons.access_time_rounded),
            const SizedBox(height: 16),
            _buildExpiringItems(onItemTap),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- HIER IST JETZT DIE API METHODE ---
  // Wir übergeben BuildContext, da wir in einem StatelessWidget sind
  Future<void> _fetchProductData(BuildContext context, String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 1) {
          final product = data['product'];
          final productName = product['product_name'] ?? 'Unbekanntes Produkt';
          
          print('Gefunden: $productName');
          
          // context.mounted prüft, ob die Seite nach der Ladezeit noch existiert
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gefunden: $productName'),
              backgroundColor: const Color(0xFF66BB6A), 
            ),
          );
        } else {
          print('Produkt nicht in der Datenbank gefunden.');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produkt leider nicht erkannt.')),
          );
        }
      }
    } catch (e) {
      print('Fehler beim Abrufen der API: $e');
    }
  }

  // --- WEITERE UI-METHODEN ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Dein Impact diesen Monat", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _impactStat("42,50 €", "Gespart", Icons.payments_outlined),
              _impactStat("12,4 kg", "CO₂ gespart", Icons.eco_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // --- DER NEUE ELEVATED BUTTON FÜR DEN WEB-BROWSER ---
  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B5E20),
          elevation: 2,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1B5E20), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        clipBehavior: Clip.none,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final icons = ["🥘", "🍝", "🥗"];
          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Center(child: Text(icons[index], style: const TextStyle(fontSize: 40))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("KI-Rezept ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text("3 Reste verwerten", style: TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12, style: BorderStyle.none),
        ),
        child: const Text('Dein Vorrat ist leer 🍎', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)),
      );
    }

    return Column(
      children: items.map((item) {
        final (color, label) = switch (item.status) {
          ExpiryStatus.expired => (Colors.red.shade700, 'Abgelaufen'),
          ExpiryStatus.today => (Colors.red.shade500, 'Heute fällig'),
          ExpiryStatus.soon => (Colors.orange.shade700, 'Noch ${item.daysLeft} Tage'),
          ExpiryStatus.ok => (AppColors.primaryGreen, 'Noch ${item.daysLeft} Tage'),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => onItemTap?.call(item),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Text(item.name.characters.first, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SquigglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF66BB6A) // Die Farbe des Kringels
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Startpunkt des Kringels
    path.moveTo(0, size.height / 2);
    
    // Eine leichte S-Kurve zeichnen
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 1.2, // Kontrollpunkt 1 (unten)
      size.width * 0.5, size.height / 2,    // Mittelpunkt
    );
    path.quadraticBezierTo(
      size.width * 0.75, -size.height * 0.2, // Kontrollpunkt 2 (oben)
      size.width, size.height / 2,          // Endpunkt
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
