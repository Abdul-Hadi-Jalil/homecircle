class InventoryItem {
  InventoryItem(Map<String, dynamic> json) : data = Map.unmodifiable(json);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get householdId => data['household_id'] as String;
  String get type => data['item_type'] as String;
  bool get consumable => type == 'consumable';
  bool get archived => data['deleted_at'] != null;
  int get revision => data['revision'] as int;
  String? get photoPath => data['photo_path'] as String?;
  String get status => (data['stock_status'] ?? data['condition']) as String;
  String get quantity => '${data['quantity'] ?? ''}';
  String get unit => data['unit'] as String? ?? '';
  String get location => data['location'] as String? ?? '';
  String get category => data['category_name'] as String? ?? 'Uncategorized';
}

String inventoryLabel(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

class InventoryPage {
  InventoryPage(this.items, this.total, this.page);
  final List<InventoryItem> items;
  final int total;
  final int page;
  factory InventoryPage.fromJson(Map<String, dynamic> json) => InventoryPage(
    (json['items'] as List)
        .map((row) => InventoryItem(row as Map<String, dynamic>))
        .toList(),
    json['total'] as int,
    json['page'] as int,
  );
}
