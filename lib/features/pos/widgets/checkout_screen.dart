import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/pos_cart_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/branch_session_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/payment_settings_provider.dart';
import 'after_sale_confirmation_dialog.dart';
import 'gcash_payment_dialog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'Cash'; // Cash, GCash, Card
  bool _isSubmitting = false;
  String? _clientSaleId;

  Future<void> _handleCompleteSale({
    required PosCartProvider cart,
    required BranchSessionProvider session,
  }) async {
    // 1. Re-validate cart stock immediately before submission
    ProductsProvider? productsProvider;
    InventoryProvider? inventoryProvider;
    try {
      productsProvider = context.read<ProductsProvider>();
    } catch (_) {}
    try {
      inventoryProvider = context.read<InventoryProvider>();
    } catch (_) {}

    if (productsProvider != null && productsProvider.isLoadingRecipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product recipes are still loading, please wait a moment.',
          ),
          backgroundColor: AppColors.mutedRed,
        ),
      );
      return;
    }

    if (inventoryProvider != null && inventoryProvider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Branch inventory is still syncing, please wait a moment.',
          ),
          backgroundColor: AppColors.mutedRed,
        ),
      );
      return;
    }

    if (productsProvider != null && inventoryProvider != null) {
      final validation = cart.validateCartStock(
        recipes: productsProvider.recipes,
        inventoryItems: inventoryProvider.items,
        allowMissingRecipes: false,
      );

      if (!validation.isValid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.mutedRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cannot Complete Sale',
                  style: AppTextStyles.dialogTitle(),
                ),
              ],
            ),
            content: Text(
              validation.errorMessage ??
                  'Items in your cart exceed available branch stock.',
              style: AppTextStyles.body(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Back to Cart', style: AppTextStyles.buttonSmall()),
              ),
            ],
          ),
        );
        return; // DO NOT clear cart!
      }
    }

    // 2. If GCash is selected, prompt for static QR scanning and reference number input
    String? gcashRef;
    if (_paymentMethod == 'GCash') {
      final paymentSettings = context.read<PaymentSettingsProvider>();
      if (!paymentSettings.isGcashAvailable || paymentSettings.settings == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GCash is currently unavailable for this branch. Please choose Cash.'),
            backgroundColor: AppColors.mutedRed,
          ),
        );
        return;
      }

      final ref = await showGcashPaymentDialog(
        context,
        settings: paymentSettings.settings!,
        totalAmount: cart.totalAmount,
      );

      // Cashier cancelled or closed the dialog without confirming payment
      if (ref == null || ref.trim().isEmpty) {
        return; // Safe exit: cart untouched, zero inventory deducted
      }
      gcashRef = ref.trim();
    }

    if (!mounted) return;

    setState(() => _isSubmitting = true);
    _clientSaleId ??=
        'SALE_${DateTime.now().millisecondsSinceEpoch}_${session.branchId}';

    try {
      final itemsCopy = List<CartItemModel>.from(cart.items);
      final totalAmount = cart.totalAmount;
      final bId = session.branchId;
      final rawBranchName = session.currentBranchName;
      final bName = rawBranchName.endsWith('Branch')
          ? rawBranchName
          : '$rawBranchName Branch';

      final txProvider = context.read<TransactionsProvider>();
      final createdTx = await txProvider.addTransaction(
        branchId: bId,
        branchName: bName,
        items: itemsCopy,
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        gcashReference: gcashRef,
        cashierId: session.currentUser?.uid ?? 'STAFF_DEVICE',
        cashierName:
            session.currentUser?.displayName ??
            session.currentUser?.email ??
            session.currentBranchName,
        clientSaleId: _clientSaleId,
      );

      // Success: reset clientSaleId and clear cart
      _clientSaleId = null;
      cart.clearCart();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AfterSaleConfirmationDialog(
            transaction: createdTx,
            onNewSale: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            onBackToDashboard: () {
              Navigator.of(ctx).popUntil((route) => route.isFirst);
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to complete sale: ${e.toString().replaceAll("Exception: ", "")}',
            style: AppTextStyles.caption(color: AppColors.surfaceWhite),
          ),
          backgroundColor: AppColors.mutedRed,
          duration: const Duration(seconds: 4),
        ),
      );
      // DO NOT clear cart! Staff can adjust or retry
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartProvider>();
    final session = context.watch<BranchSessionProvider>();
    final paymentSettings = context.watch<PaymentSettingsProvider>();
    final isGcashAvailable = paymentSettings.isGcashAvailable;

    if (!isGcashAvailable && _paymentMethod == 'GCash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _paymentMethod = 'Cash');
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout Confirmation',
          style: AppTextStyles.pageTitle(fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branch & Order summary header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.latteBeige,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.darkCoffee,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${session.currentBranchName} Branch',
                                style: AppTextStyles.cardTitle(
                                  fontSize: 16,
                                  color: AppColors.darkCoffee,
                                ),
                              ),
                              Text(
                                'Branch ID: ${session.branchId}',
                                style: AppTextStyles.caption(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Order Summary',
                      style: AppTextStyles.sectionHeading(
                        fontSize: 18,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items list
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.latteBeige,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cart.items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: AppColors.latteBeige),
                          itemBuilder: (context, index) {
                            final item = cart.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.darkCoffee
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      '${item.quantity}',
                                      style: AppTextStyles.badge(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkCoffee,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: AppTextStyles.cardTitle(
                                            fontSize: 14,
                                            color: AppColors.darkCoffee,
                                          ),
                                        ),
                                        Text(
                                          item.variantLabel,
                                          style: AppTextStyles.caption(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₱${item.subtotal.toStringAsFixed(2)}',
                                    style: AppTextStyles.price(
                                      fontSize: 14,
                                      color: AppColors.darkCoffee,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Payment Method',
                      style: AppTextStyles.sectionHeading(
                        fontSize: 18,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Payment Method Options: Cash, GCash
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.money_rounded,
                              size: 16,
                              color: _paymentMethod == 'Cash'
                                  ? AppColors.surfaceWhite
                                  : AppColors.darkCoffee,
                            ),
                            label: Text(
                              'Cash',
                              style: AppTextStyles.navLabel(
                                fontSize: 12,
                                color: _paymentMethod == 'Cash'
                                    ? AppColors.surfaceWhite
                                    : AppColors.textSecondary,
                              ),
                            ),
                            selected: _paymentMethod == 'Cash',
                            selectedColor: AppColors.darkCoffee,
                            backgroundColor: AppColors.surfaceWhite,
                            side: BorderSide(
                              color: _paymentMethod == 'Cash'
                                  ? AppColors.darkCoffee
                                  : AppColors.latteBeige,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _paymentMethod = 'Cash');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.phone_android_rounded,
                              size: 16,
                              color: _paymentMethod == 'GCash'
                                  ? AppColors.surfaceWhite
                                  : (isGcashAvailable
                                      ? AppColors.darkCoffee
                                      : AppColors.textMuted.withValues(alpha: 0.5)),
                            ),
                            label: Text(
                              isGcashAvailable ? 'GCash' : 'GCash (Unavailable)',
                              style: AppTextStyles.navLabel(
                                fontSize: 12,
                                color: _paymentMethod == 'GCash'
                                    ? AppColors.surfaceWhite
                                    : (isGcashAvailable
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted.withValues(alpha: 0.5)),
                              ),
                            ),
                            selected: _paymentMethod == 'GCash',
                            selectedColor: AppColors.darkCoffee,
                            backgroundColor: AppColors.surfaceWhite,
                            side: BorderSide(
                              color: _paymentMethod == 'GCash'
                                  ? AppColors.darkCoffee
                                  : (isGcashAvailable
                                      ? AppColors.latteBeige
                                      : AppColors.latteBeige.withValues(alpha: 0.5)),
                            ),
                            onSelected: isGcashAvailable
                                ? (selected) {
                                    if (selected) {
                                      setState(() => _paymentMethod = 'GCash');
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),

                    if (!isGcashAvailable) ...[
                      const SizedBox(height: 6),
                      Text(
                        paymentSettings.isLoading
                            ? 'Checking branch payment settings...'
                            : (paymentSettings.isPermissionDenied
                                ? 'GCash payment unavailable (branch settings permission restricted).'
                                : 'GCash static QR is not configured or disabled for this branch.'),
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Pricing breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.latteBeige),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: AppTextStyles.tableCell(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '₱${cart.totalAmount.toStringAsFixed(2)}',
                                style: AppTextStyles.price(
                                  fontSize: 14,
                                  color: AppColors.darkCoffee,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tax / VAT',
                                style: AppTextStyles.tableCell(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Included (0.00)',
                                style: AppTextStyles.tableCell(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 20,
                            color: AppColors.latteBeige,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Grand Total',
                                style: AppTextStyles.sectionHeading(
                                  fontSize: 18,
                                  color: AppColors.darkCoffee,
                                ),
                              ),
                              Text(
                                '₱${cart.totalAmount.toStringAsFixed(2)}',
                                style: AppTextStyles.price(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkCoffee,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Complete Sale Bar
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppColors.latteBeige, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCoffee,
                    foregroundColor: AppColors.surfaceWhite,
                  ),
                  onPressed: (cart.isEmpty || _isSubmitting)
                      ? null
                      : () => _handleCompleteSale(cart: cart, session: session),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSubmitting ? 'Processing...' : 'Complete Sale',
                    style: AppTextStyles.button(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
