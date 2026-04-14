import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'food_item.dart';

class Recipe {
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final int durationMinutes;

  Recipe({
    required this.name,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.durationMinutes,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        name: json['name'] as String,
        description: json['description'] as String,
        ingredients: (json['ingredients'] as List<dynamic>).cast<String>(),
        steps: (json['steps'] as List<dynamic>).cast<String>(),
        durationMinutes: (json['durationMinutes'] as num).toInt(),
      );
}

class RecipeService {
  static const _apiKeyPref = 'groq_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  static Future<List<Recipe>> fetchRecipes(List<FoodItem> expiringItems) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('kein_api_key');
    }

    final itemNames = expiringItems.map((i) => i.name).join(', ');

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'system',
            'content': 'Du bist ein Kochassistent. Antworte ausschließlich mit gültigem JSON, ohne zusätzlichen Text.',
          },
          {
            'role': 'user',
            'content': '''Schlage 3 einfache Rezepte vor, die folgende Lebensmittel verwenden, die bald ablaufen: $itemNames.

Antworte NUR mit einem gültigen JSON-Array:
[
  {
    "name": "Rezeptname",
    "description": "Kurze appetitliche Beschreibung (1-2 Sätze)",
    "ingredients": ["Zutat 1 mit Menge", "Zutat 2 mit Menge"],
    "steps": ["Schritt 1", "Schritt 2", "Schritt 3"],
    "durationMinutes": 30
  }
]''',
          }
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) throw Exception('ungültiger_api_key');
    if (response.statusCode != 200) {
      throw Exception('API-Fehler ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['choices'] as List<dynamic>)[0]['message']['content'] as String;

    // JSON aus der Antwort extrahieren
    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (jsonMatch == null) throw Exception('Ungültiges Antwortformat');

    final list = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
    return list.map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
  }
}
