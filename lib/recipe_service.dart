import 'dart:convert';
import 'package:http/http.dart' as http;
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
  // Supabase-Projekt-URL und Anon-Key (öffentlich, kein Geheimnis)
  // Nach dem Deployen hier eintragen:
  static const _supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
  static const _supabaseAnonKey = 'YOUR_ANON_KEY';

  static Future<List<Recipe>> fetchRecipes(List<FoodItem> expiringItems) async {
    final itemNames = expiringItems.map((i) => i.name).join(', ');

    final response = await http.post(
      Uri.parse('$_supabaseUrl/functions/v1/recipe-proxy'),
      headers: {
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'ingredients': itemNames}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Supabase-Authentifizierung fehlgeschlagen.');
    }
    if (response.statusCode != 200) {
      throw Exception('Server-Fehler ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        (data['choices'] as List<dynamic>)[0]['message']['content'] as String;

    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (jsonMatch == null) throw Exception('Ungültiges Antwortformat');

    final list = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
    return list.map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
  }
}
