import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shows a dialog allowing direct numeric quantity editing.
/// Strictly enforces positive whole numbers and upper bounds from inventory/recipes.
Future<int?> showQuantityEditDialog(
  BuildContext context, {
  String title = 'Edit Quantity',
  String? itemName,
  required int currentQuantity,
  int? maxQuantity,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => QuantityEditDialog(
      title: title,
      itemName: itemName,
      currentQuantity: currentQuantity,
      maxQuantity: maxQuantity,
    ),
  );
}

class QuantityEditDialog extends StatefulWidget {
  final String title;
  final String? itemName;
  final int currentQuantity;
  final int? maxQuantity;

  const QuantityEditDialog({
    super.key,
    required this.title,
    this.itemName,
    required this.currentQuantity,
    this.maxQuantity,
  });

  @override
  State<QuantityEditDialog> createState() => _QuantityEditDialogState();
}

class _QuantityEditDialogState extends State<QuantityEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentQuantity.toString());
    // Select all text so the user can immediately type a replacement number
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final val = int.tryParse(_controller.text.trim());
    if (val != null && val > 0) {
      Navigator.pop(context, val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxQty = widget.maxQuantity;

    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.latteBeige, width: 1),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.cardTitle(
              fontSize: 17,
              color: AppColors.darkCoffee,
            ),
          ),
          if (widget.itemName != null && widget.itemName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.itemName!,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: AppTextStyles.statNumber(
                fontSize: 20,
                color: AppColors.darkCoffee,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                labelText: 'Quantity',
                labelStyle: AppTextStyles.formLabel(),
                hintText: 'Enter quantity',
                hintStyle: AppTextStyles.caption(),
                filled: true,
                fillColor: AppColors.warmCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.latteBeige),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.latteBeige),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.darkCoffee, width: 1.5),
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Enter a quantity';
                }
                final parsed = int.tryParse(text);
                if (parsed == null) {
                  return 'Enter a valid whole number';
                }
                if (parsed <= 0) {
                  return 'Quantity must be at least 1';
                }
                if (maxQty != null && maxQty > 0 && parsed > maxQty) {
                  return 'Cannot exceed available stock ($maxQty)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.button(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkCoffee,
            foregroundColor: AppColors.surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _submit,
          child: Text(
            'Set Quantity',
            style: AppTextStyles.button(color: AppColors.surfaceWhite),
          ),
        ),
      ],
    );
  }
}

