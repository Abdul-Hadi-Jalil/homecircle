import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../tasks/widgets/task_widgets.dart';
import '../models/shopping_item.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../views/shopping_item_form.dart';
import 'shopping_widgets.dart';

const shoppingCurrencies = [
  'PKR',
  'USD',
  'EUR',
  'GBP',
  'AED',
  'SAR',
  'INR',
  'CAD',
  'AUD',
  'JPY',
  'CNY',
];

Future<void> purchaseShopping(BuildContext context, ShoppingItem item) async {
  final vm = context.read<ShoppingListViewModel>(),
      captured = context.read<ShoppingListViewModel>().scope;
  final result = await showModalBottomSheet<ShoppingItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ShoppingPurchaseSheet(item),
  );
  if (!context.mounted || !vm.current(captured) || result == null) return;
  final l = context.taskCopy;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l.shoppingPurchaseSuccess)));
  if (result.canApply) await promptShoppingInventory(context, result);
}

Future<void> promptShoppingInventory(
  BuildContext context,
  ShoppingItem item,
) async {
  final vm = context.read<ShoppingListViewModel>(),
      captured = context.read<ShoppingListViewModel>().scope,
      l = context.taskCopy;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.shoppingInventoryQuestion),
      content: Text(
        '${item.actualQuantity} ${item.unit ?? ''} · ${item.linkedItemName ?? item.title}\n${l.shoppingInventoryHelp}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.shoppingNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.shoppingUpdateInventory),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted || !vm.current(captured)) return;
  final success = await vm.apply(item);
  if (context.mounted && vm.current(captured)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? l.shoppingInventorySuccess : l.shoppingInventoryFailure,
        ),
      ),
    );
  }
}

Future<void> undoShopping(BuildContext context, ShoppingItem item) async {
  final vm = context.read<ShoppingListViewModel>(),
      captured = context.read<ShoppingListViewModel>().scope,
      l = context.taskCopy;
  if (await confirmTask(
        context,
        item.purchased ? l.shoppingUndo : l.taskReopen,
        message: item.purchased ? l.shoppingUndoHelp : l.taskReopenedHelp,
      ) &&
      context.mounted &&
      vm.current(captured)) {
    final result = await vm.action(item, 'undo-purchase');
    if (result != null && context.mounted && vm.current(captured)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.shoppingUndoSuccess)));
    }
  }
}

class ShoppingPurchaseSheet extends StatefulWidget {
  const ShoppingPurchaseSheet(this.item, {super.key});
  final ShoppingItem item;
  @override
  State<ShoppingPurchaseSheet> createState() => _ShoppingPurchaseSheetState();
}

class _ShoppingPurchaseSheetState extends State<ShoppingPurchaseSheet> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController(),
      price = TextEditingController(),
      note = TextEditingController();
  String? currency;
  late final String scope;
  @override
  void initState() {
    super.initState();
    scope = context.read<ShoppingListViewModel>().scope;
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<ShoppingListViewModel>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(widget.item.amount),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantity,
                enabled: !vm.busy,
                decoration: InputDecoration(
                  labelText: l.shoppingActualQuantity,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => shoppingNumber(v, context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                enabled: !vm.busy,
                decoration: InputDecoration(labelText: l.shoppingPrice),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    shoppingNumber(v, context, price: true) ??
                    ((v?.trim().isNotEmpty == true) != (currency != null)
                        ? l.shoppingPriceError
                        : null),
              ),
              const SizedBox(height: 12),
              taskDropdown(
                l.shoppingCurrency,
                currency ?? '',
                [
                  ('', l.taskAny),
                  for (final code in shoppingCurrencies) (code, code),
                ],
                vm.busy
                    ? null
                    : (v) => setState(() => currency = v == '' ? null : v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                maxLength: 4000,
                maxLines: 2,
                enabled: !vm.busy,
                decoration: InputDecoration(labelText: l.shoppingNote),
              ),
              if (vm.error != null)
                TaskNotice(shoppingError(context, vm.error)),
              FilledButton(
                onPressed: vm.busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate() ||
                            !vm.current(scope)) {
                          return;
                        }
                        final result = await vm.action(
                          widget.item,
                          'purchase',
                          fields: {
                            'actual_quantity': quantity.text.trim().isEmpty
                                ? null
                                : quantity.text.trim(),
                            'purchase_price': price.text.trim().isEmpty
                                ? null
                                : price.text.trim(),
                            'currency_code': currency,
                            'completion_note': note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          },
                        );
                        if (context.mounted &&
                            vm.current(scope) &&
                            result != null) {
                          Navigator.pop(context, result);
                        }
                      },
                child: Text(vm.busy ? l.taskSaving : l.shoppingMarkPurchased),
              ),
              TextButton(
                onPressed: vm.busy ? null : () => Navigator.pop(context),
                child: Text(l.taskDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
