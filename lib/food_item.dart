import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FoodItem {
  final String name;
  final String category;
  final DateTime expiryDate;
  final String? barcode;

  FoodItem({
    required this.name,
    required this.category,
    required this.expiryDate,
    this.barcode,
  });

  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;

  ExpiryStatus get status {
    if (daysLeft < 0) return ExpiryStatus.expired;
    if (daysLeft == 0) return ExpiryStatus.today;
    if (daysLeft <= 3) return ExpiryStatus.soon;
    return ExpiryStatus.ok;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'expiryDate': expiryDate.toIso8601String(),
        'barcode': barcode,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String,
        category: json['category'] as String,
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        barcode: json['barcode'] as String?,
      );
}

enum ExpiryStatus { expired, today, soon, ok }

class FoodStore {
  static final List<FoodItem> items = [];
  static const _key = 'food_items';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return;
    final list = jsonDecode(jsonStr) as List<dynamic>;
    items
      ..clear()
      ..addAll(list.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)));
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
