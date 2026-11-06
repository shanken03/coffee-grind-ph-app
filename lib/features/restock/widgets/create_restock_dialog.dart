import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/ingredient_model.dart';
import '../../../providers/restock_provider.dart';
import '../../../providers/branch_session_provider.dart';
import '../../../providers/inventory_provider.dart';

class CreateRestockDialog extends StatefulWidget {
  const CreateRestockDialog({super.key});

  @override
  State<CreateRestockDialog> createState() => _CreateRestockDialogState();
}

class _CreateRestockDialogState extends State<CreateRestockDialog> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Ingredients';
  String? _selectedIngredientId;
  final TextEditingController _qtyController = TextEditingController(
    text: '10',
  );
  final TextEditingController _unitController = TextEditingController(
    text: 'pcs',
  );
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'Ingredients',
    'Packaging / Supplies',
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();
    final restockProvider = context.watch<RestockProvider>();
    InventoryProvider? inventoryProvider;
    try {
      inventoryProvider = context.watch<InventoryProvider>();
    } catch (_) {}

    List<IngredientModel> masterItems = restockProvider.ingredients;
    if (masterItems.isEmpty &&
        inventoryProvider != null &&
        inventoryProvider.items.isNotEmpty) {
      masterItems = inventoryProvider.items.map((inv) {
        final catLower = inv.category.toLowerCase();
        final isPack =
            catLower.contains('pack') ||
            catLower.contains('suppl') ||
            inv.ingredientId.startsWith('pkg_') ||
            inv.id.contains('pkg_');
        return IngredientModel(
          ingredientId: inv.ingredientId,
          name: inv.name,
          unit: inv.unit,
          itemType: isPack ? 'packaging' : 'ingredient',
          status: 'active',
        );
      }).toList();
    }

    final List<IngredientModel> availableItems =
        _selectedCategory == 'Ingredients'
        ? masterItems.where((i) => i.isIngredient && i.isActive).toList()
        : masterItems.where((i) => i.isPackaging && i.isActive).toList();

    IngredientModel? activeIngredient;
    if (availableItems.isNotEmpty) {
      activeIngredient = availableItems.firstWhere(
        (i) => i.ingredientId == _selectedIngredientId,
        orElse: () => availableItems.first,
      );
    }

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.latteBeige, width: 1),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Request Restocking',
                      style: AppTextStyles.dialogTitle(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Branch: ${session.currentBranchName} (${session.branchId})',
                  style: AppTextStyles.caption(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Category selection
                Text('Item Category', style: AppTextStyles.formLabel()),
                const SizedBox(height: 6),
                Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: AppTextStyles.navLabel(
                              fontSize: 12,
                              color: isSelected
                                  ? AppColors.surfaceWhite
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.darkCoffee,
                          backgroundColor: AppColors.surfaceWhite,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.darkCoffee
                                : AppColors.latteBeige,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                                _selectedIngredientId = null;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Item Type Dropdown
                Text('Select Item', style: AppTextStyles.formLabel()),
                const SizedBox(height: 6),
                if (restockProvider.isLoadingIngredients)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warmCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.latteBeige),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading master ingredients...',
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (availableItems.isEmpty && restockProvider.hasIngredientsError)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mutedRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.mutedRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.mutedRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Failed to load ingredients: ${restockProvider.ingredientsErrorMessage}',
                                style: AppTextStyles.caption(
                                  color: AppColors.mutedRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                restockProvider.retryLoadIngredients(),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppColors.darkCoffee,
                            ),
                            label: Text(
                              'Retry',
                              style: AppTextStyles.button(
                                color: AppColors.darkCoffee,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.latteBeige
                                  .withValues(alpha: 0.3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (availableItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warmCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.latteBeige),
                    ),
                    child: Text(
                      'No active ${_selectedCategory.toLowerCase()} found in master catalog',
                      style: AppTextStyles.caption(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<IngredientModel>(
                    initialValue: activeIngredient,
                    dropdownColor: AppColors.surfaceWhite,
                    style: AppTextStyles.body(color: AppColors.darkCoffee),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: availableItems.map((item) {
                      return DropdownMenuItem<IngredientModel>(
                        value: item,
                        child: Text(
                          item.name,
                          style: AppTextStyles.body(
                            color: AppColors.darkCoffee,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedIngredientId = val.ingredientId;
                          _unitController.text = val.unit;
                        });
                      }
                    },
                  ),

                const SizedBox(height: 16),

                // Quantity & Unit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity', style: AppTextStyles.formLabel()),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _qtyController,
                            style: AppTextStyles.inputField(),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null ||
                                  val.isEmpty ||
                                  int.tryParse(val) == null ||
                                  int.parse(val) <= 0) {
                                return 'Enter valid quantity';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Unit', style: AppTextStyles.formLabel()),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _unitController,
                            style: AppTextStyles.inputField(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Optional Note
                Text('Optional Note', style: AppTextStyles.formLabel()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: AppTextStyles.inputField(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Low stock for upcoming weekend rush...',
                    hintStyle: AppTextStyles.inputHint(),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCoffee,
                      foregroundColor: AppColors.surfaceWhite,
                    ),
                    onPressed:
                        (_isSubmitting ||
                            activeIngredient == null ||
                            restockProvider.isLoadingIngredients)
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(context);
                              try {
                                final qty = int.parse(
                                  _qtyController.text.trim(),
                                );
                                final restockProv = context
                                    .read<RestockProvider>();
                                final selected = activeIngredient!;
                                final bName =
                                    session.currentBranchName.endsWith('Branch')
                                    ? session.currentBranchName
                                    : '${session.currentBranchName} Branch';
                                await restockProv.addRequest(
                                  branchId: session.branchId,
                                  branchName: bName,
                                  category: _selectedCategory,
                                  itemType: selected.name,
                                  quantity: qty,
                                  unit: _unitController.text.trim(),
                                  note: _noteController.text.trim().isNotEmpty
                                      ? _noteController.text.trim()
                                      : null,
                                  ingredientId: selected.ingredientId,
                                  ingredientName: selected.name,
                                  staffId:
                                      session.currentUser?.uid ??
                                      'STAFF_DEVICE',
                                  staffName:
                                      session.currentUser?.displayName ??
                                      session.currentUser?.email ??
                                      'Store Staff',
                                );
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Restocking request for ${selected.name} sent to Owner Web (Pending).',
                                      style: AppTextStyles.caption(
                                        color: AppColors.darkCoffee,
                                      ),
                                    ),
                                    backgroundColor: AppColors.surfaceWhite,
                                  ),
                                );
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to submit restock request: ${e.toString().replaceAll("Exception: ", "")}',
                                        style: AppTextStyles.caption(
                                          color: AppColors.surfaceWhite,
                                        ),
                                      ),
                                      backgroundColor: AppColors.mutedRed,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surfaceWhite,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : 'Submit Restock Request',
                      style: AppTextStyles.button(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
