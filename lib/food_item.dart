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
}

enum ExpiryStatus { expired, today, soon, ok }

/// Einfacher In-Memory-Store, bis echtes State Management kommt.
class FoodStore {
  static final List<FoodItem> items = [
    FoodItem(
      name: 'Milch',
      category: 'Milchprodukte',
      expiryDate: DateTime.now().add(const Duration(days: 1)),
    ),
    FoodItem(
      name: 'Tomaten',
      category: 'Gemüse',
      expiryDate: DateTime.now(),
    ),
    FoodItem(
      name: 'Vollkornbrot',
      category: 'Backwaren',
      expiryDate: DateTime.now().add(const Duration(days: 5)),
    ),
    FoodItem(
      name: 'Joghurt',
      category: 'Milchprodukte',
      expiryDate: DateTime.now().add(const Duration(days: 10)),
    ),
  ];
}
