import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/branch_payment_settings_model.dart';

/// Displays the branch-specific static GCash QR dialog for customer scanning
/// and cashier reference number verification before sale completion.
Future<String?> showGcashPaymentDialog(
  BuildContext context, {
  required BranchPaymentSettingsModel settings,
  required double totalAmount,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GcashPaymentDialog(
      settings: settings,
      totalAmount: totalAmount,
    ),
  );
}

class GcashPaymentDialog extends StatefulWidget {
  final BranchPaymentSettingsModel settings;
  final double totalAmount;

  const GcashPaymentDialog({
    super.key,
    required this.settings,
    required this.totalAmount,
  });

  @override
  State<GcashPaymentDialog> createState() => _GcashPaymentDialogState();
}

class _GcashPaymentDialogState extends State<GcashPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _refController = TextEditingController();

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final ref = _refController.text.trim();
    Navigator.of(context).pop(ref);
  }

  Widget _buildQrImage() {
    final qrUrl = widget.settings.gcashQrImageUrl.trim();

    if (!widget.settings.hasValidQrUrl) {
      return _buildImageFallback('Invalid QR Code URL.');
    }

    if (kIsWeb) {
      return Image.network(
        qrUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading();
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildImageFallback('Unable to load QR image.'),
      );
    }

    return CachedNetworkImage(
      imageUrl: qrUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => _buildLoading(),
      errorWidget: (context, url, error) =>
          _buildImageFallback('Unable to load QR image. Check connection.'),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: AppColors.warmCream,
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.darkCoffee,
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback(String message) {
    return Container(
      color: AppColors.warmCream,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: AppColors.mutedRed,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(color: AppColors.mutedRed),
          ),
          const SizedBox(height: 4),
          Text(
            'Ask customer to use the manual account details below.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAccountName = widget.settings.accountName.isNotEmpty;
    final hasAccountNumber = widget.settings.accountNumber.isNotEmpty;

    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.latteBeige, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GCash QR Payment',
                  style: AppTextStyles.cardTitle(
                    fontSize: 17,
                    color: AppColors.darkCoffee,
                  ),
                ),
                Text(
                  widget.settings.branchName.isNotEmpty
                      ? widget.settings.branchName
                      : 'Scan & Pay',
                  style: AppTextStyles.caption(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exact Order Total Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkCoffee.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.latteBeige),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exact Amount to Pay:',
                      style: AppTextStyles.caption(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    Text(
                      '₱${widget.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.statNumber(
                        fontSize: 20,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // QR Image Container (BoxFit.contain, preserves original QR bytes)
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.latteBeige, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildQrImage(),
                ),
              ),

              const SizedBox(height: 10),

              // Manual Account Details Fallback
              if (hasAccountName || hasAccountNumber)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.latteBeige),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasAccountName)
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Account: ${widget.settings.accountName}',
                              style: AppTextStyles.caption(
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                          ],
                        ),
                      if (hasAccountName && hasAccountNumber)
                        const SizedBox(height: 4),
                      if (hasAccountNumber)
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Number: ${widget.settings.accountNumber}',
                              style: AppTextStyles.caption(
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // Cashier Verification Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cashier verification required: Inspect the customer receipt on their phone to verify recipient and exact amount before confirming.',
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Required GCash Reference Number Input
              TextFormField(
                controller: _refController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirm(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                ],
                style: AppTextStyles.inputField(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'GCash Reference Number *',
                  labelStyle: AppTextStyles.formLabel(fontSize: 13),
                  hintText: 'Enter 13-digit reference from customer receipt',
                  hintStyle: AppTextStyles.inputHint(fontSize: 12),
                  prefixIcon: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.darkCoffee,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.warmCream,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.darkCoffee,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Enter GCash reference number';
                  }
                  if (text.length < 4) {
                    return 'Reference number is too short';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _confirm,
          child: Text(
            'Confirm Payment',
            style: AppTextStyles.button(color: AppColors.surfaceWhite),
          ),
        ),
      ],
    );
  }
}
