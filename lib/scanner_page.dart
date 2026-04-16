import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  
  bool _isProcessing = false; 
  String? _scannedBarcode;
  String? _productName;
  
  // HIER IST DIE NEUERUNG: Eine Liste, die sich alle Scans dieser Session merkt
  final List<String> _scannedSessionItems = [];

  Future<void> _fetchProduct(String barcode) async {
    setState(() {
      _isProcessing = true;
      _scannedBarcode = barcode;
      _productName = null;
    });

    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          setState(() => _productName = data['product']['product_name'] ?? 'Unbekanntes Produkt');
        } else {
          setState(() => _productName = 'Produkt nicht gefunden');
        }
      }
    } catch (e) {
      setState(() => _productName = 'Fehler beim Laden');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        // Wir zeigen im Titel an, wie viele Artikel schon gescannt wurden!
        title: Text('Gescannt: ${_scannedSessionItems.length}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Kamera-Wechsel jetzt oben links
        leading: IconButton(
          icon: const Icon(Icons.flip_camera_ios),
          onPressed: () => cameraController.switchCamera(),
        ),
        // Das X zum Schließen oben rechts
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 30),
            onPressed: () {
              // Beim X-Klick geben wir die GANZE LISTE an den HomeScreen zurück
              Navigator.pop(context, _scannedSessionItems);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- OBERE HÄLFTE: KAMERA ---
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      if (_isProcessing || _productName != null) return;
                      
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _fetchProduct(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF66BB6A), width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // --- UNTERE HÄLFTE: ERGEBNIS ---
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isProcessing && _scannedBarcode == null) ...[
                    const Icon(Icons.qr_code_scanner_rounded, size: 60, color: Colors.black26),
                    const SizedBox(height: 16),
                    const Text("Halte einen Barcode in den Rahmen", style: TextStyle(fontSize: 18, color: Colors.black54)),
                  ]
                  else if (_isProcessing) ...[
                    const CircularProgressIndicator(color: Color(0xFF1B5E20)),
                    const SizedBox(height: 24),
                    Text("Suche nach Barcode...", style: const TextStyle(color: Colors.black54)),
                  ]
                  else if (_productName != null) ...[
                    const Icon(Icons.check_circle_outline_rounded, size: 60, color: Color(0xFF66BB6A)),
                    const SizedBox(height: 16),
                    Text(
                      _productName!,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            // Einfach nur verwerfen und weiter scannen
                            setState(() {
                              _scannedBarcode = null;
                              _productName = null;
                            });
                          },
                          child: const Text("Verwerfen"),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            // 1. Zur Liste hinzufügen
                            _scannedSessionItems.add(_productName!);
                            
                            // 2. Zustand zurücksetzen, damit die Kamera sofort das nächste Produkt scannen kann
                            setState(() {
                              _scannedBarcode = null;
                              _productName = null;
                            });
                          },
                          child: const Text("Merken & Weiter"),
                        ),
                      ],
                    )
                  ]
                ],
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