import '../../tasks/models/household_task.dart';

class ShoppingItem extends HouseholdTask {
  ShoppingItem(super.json) {
    if (kind != TaskKind.shopping ||
        (status == TaskStatus.completed) !=
            (data['purchase_id'] != null &&
                data['purchased_by'] != null &&
                data['purchased_at'] != null)) {
      throw const FormatException('Inconsistent shopping response');
    }
  }
  String? get quantity => data['quantity'] as String?;
  String? get actualQuantity => data['actual_quantity'] as String?;
  String? get unit => data['unit'] as String?;
  String? get purchaseId => data['purchase_id'] as String?;
  bool get purchased => status == TaskStatus.completed;
  bool get inventoryApplied => data['inventory_updated_at'] != null;
  bool get canApply =>
      purchased &&
      linkedItemId != null &&
      actualQuantity != null &&
      data['linked_inventory_type'] == 'consumable';
  String get amount => [
    purchased ? actualQuantity : quantity,
    unit,
  ].whereType<String>().join(' ');
}
