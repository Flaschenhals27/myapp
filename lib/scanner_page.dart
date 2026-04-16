import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Wir definieren ein kleines Modell für die Liste
class ScannedProduct {
  final String barcode;
  final String name;
  final String imageUrl;
  int quantity;

  ScannedProduct({
    required this.barcode,
    required this.name,
    required this.imageUrl,
    this.quantity = 1,
  });
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  
  // Die Liste der Produkte, die wir während dieser Session scannen
  final List<ScannedProduct> _scannedProducts = [];
  
  // Hilfsvariable, um Mehrfachscans in Millisekunden zu verhindern
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;

  Future<void> _handleBarcode(String barcode) async {
    // Verhindert, dass der gleiche Barcode innerhalb von 2 Sekunden 
    // mehrfach als "neu" getriggert wird (Prellen)
    final now = DateTime.now();
    if (_lastScannedBarcode == barcode && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    
    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    // Prüfen, ob das Produkt schon in unserer Liste ist
    int existingIndex = _scannedProducts.indexWhere((p) => p.barcode == barcode);

    if (existingIndex != -1) {
      // Wenn ja: Menge erhöhen
      setState(() {
        _scannedProducts[existingIndex].quantity++;
      });
    } else {
      // Wenn nein: API fragen und neu hinzufügen
      await _fetchAndAddProduct(barcode);
    }
  }

  Future<void> _fetchAndAddProduct(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          final productData = data['product'];
          final name = productData['product_name'] ?? 'Unbekanntes Produkt';
          final image = productData['image_small_url'] ?? ''; // Kleines Vorschaubild

          setState(() {
            // Ganz oben in die Liste einfügen
            _scannedProducts.insert(0, ScannedProduct(
              barcode: barcode,
              name: name,
              imageUrl: image,
            ));
          });
        }
      }
    } catch (e) {
      debugPrint('API Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        title: Text('${_scannedProducts.length} Artikel gescannt'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF1B5E20), size: 30),
            onPressed: () => Navigator.pop(context, _scannedProducts),
          ),
        ],
      ),
      body: Column(
        children: [
          // OBERE HÄLFTE: KAMERA (etwas kleiner für mehr Platz in der Liste)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: MobileScanner(
                controller: cameraController,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    if (barcode.rawValue != null) {
                      _handleBarcode(barcode.rawValue!);
                    }
                  }
                },
              ),
            ),
          ),

          // UNTERE HÄLFTE: DIE LIVE-LISTE
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: _scannedProducts.isEmpty
                  ? const Center(child: Text("Scanne ein Produkt...", style: TextStyle(color: Colors.black26)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _scannedProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _scannedProducts[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(product.imageUrl, fit: BoxFit.cover)
                                : const Icon(Icons.fastfood_outlined),
                          ),
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("MHD: Tippe zum Einstellen", style: TextStyle(fontSize: 12, color: Colors.orange)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "x${product.quantity}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}