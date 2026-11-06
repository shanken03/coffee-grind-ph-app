import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reusable, responsive pagination controls matching the Coffee Grind PH design system.
/// Supports compact controls for mobile phones and full page-number indicators for tablets.
class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String itemName;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    this.pageSizeOptions = const [5, 10, 15, 20],
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.itemName = 'items',
  });

  int get startIndex => totalItems == 0 ? 0 : (currentPage - 1) * pageSize + 1;
  int get endIndex => min(currentPage * pageSize, totalItems);

  bool get canGoPrevious => currentPage > 1;
  bool get canGoNext => currentPage < totalPages;

  List<int?> _getPageNumbers() {
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int?>[];
    pages.add(1);

    if (currentPage > 3) {
      pages.add(null); // Ellipsis
    }

    final start = max(2, currentPage - 1);
    final end = min(totalPages - 1, currentPage + 1);

    for (int p = start; p <= end; p++) {
      pages.add(p);
    }

    if (currentPage < totalPages - 2) {
      pages.add(null); // Ellipsis
    }

    pages.add(totalPages);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWideTablet = width >= 850;
        final isMediumTablet = width >= 500 && width < 850;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            border: Border(
              top: BorderSide(color: AppColors.latteBeige, width: 1),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isWideTablet ? 20 : 12,
            vertical: isWideTablet ? 10 : 8,
          ),
          child: isWideTablet
              ? _buildSingleRowTabletLayout()
              : (isMediumTablet ? _buildTwoRowTabletLayout() : _buildMobileLayout()),
        );
      },
    );
  }

  /// Wide Tablet Layout (>= 750dp): Everything in one clean, horizontal row.
  Widget _buildSingleRowTabletLayout() {
    return Row(
      children: [
        // Summary
        Text(
          'Showing $startIndex–$endIndex of $totalItems $itemName',
          style: AppTextStyles.tableCell(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkCoffee,
          ),
        ),
        const SizedBox(width: 14),

        // Page Size Selector
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Show: ',
              style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
            ),
            _buildPageSizeDropdown(),
          ],
        ),

        const Spacer(),

        // Previous Button
        _buildNavButton(
          label: 'Previous',
          icon: Icons.chevron_left_rounded,
          isEnabled: canGoPrevious,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 6),

        // Page Numbers
        ..._buildPageNumberButtons(),
        const SizedBox(width: 6),

        // Next Button
        _buildNavButton(
          label: 'Next',
          icon: Icons.chevron_right_rounded,
          isEnabled: canGoNext,
          onTap: () => onPageChanged(currentPage + 1),
          isTrailingIcon: true,
        ),
      ],
    );
  }

  /// Medium Tablet Layout (500–749dp): Two clean rows, showing full page number buttons on bottom row.
  Widget _buildTwoRowTabletLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing $startIndex–$endIndex of $totalItems $itemName',
              style: AppTextStyles.tableCell(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCoffee,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Items per page: ',
                  style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                ),
                _buildPageSizeDropdown(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton(
              label: 'Previous',
              icon: Icons.chevron_left_rounded,
              isEnabled: canGoPrevious,
              onTap: () => onPageChanged(currentPage - 1),
            ),
            const SizedBox(width: 6),
            ..._buildPageNumberButtons(),
            const SizedBox(width: 6),
            _buildNavButton(
              label: 'Next',
              icon: Icons.chevron_right_rounded,
              isEnabled: canGoNext,
              onTap: () => onPageChanged(currentPage + 1),
              isTrailingIcon: true,
            ),
          ],
        ),
      ],
    );
  }

  /// Mobile layout (< 500dp): 2 compact rows with [ < ] Page X of Y [ > ] to prevent overflow.
  Widget _buildMobileLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top info row: count + page size
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Showing $startIndex–$endIndex of $totalItems $itemName',
                style: AppTextStyles.tableCell(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkCoffee,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Per page: ',
                  style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                ),
                _buildPageSizeDropdown(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Bottom navigation row: [ < ] Page 2 of 5 [ > ]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton(
              label: 'Previous',
              icon: Icons.chevron_left_rounded,
              isEnabled: canGoPrevious,
              onTap: () => onPageChanged(currentPage - 1),
              isCompact: true,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.forestGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Page $currentPage of $totalPages',
                style: AppTextStyles.badge(
                  fontSize: 12,
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildNavButton(
              label: 'Next',
              icon: Icons.chevron_right_rounded,
              isEnabled: canGoNext,
              onTap: () => onPageChanged(currentPage + 1),
              isTrailingIcon: true,
              isCompact: true,
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildPageNumberButtons() {
    return _getPageNumbers().map((p) {
      if (p == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '•••',
            style: AppTextStyles.caption(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        );
      }
      final isActive = p == currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: isActive ? null : () => onPageChanged(p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.forestGreen : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.forestGreen : AppColors.latteBeige,
                width: 1,
              ),
            ),
            child: Text(
              '$p',
              style: AppTextStyles.badge(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? AppColors.surfaceWhite : AppColors.darkCoffee,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPageSizeDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.latteBeige),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: pageSize,
          isDense: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.darkCoffee,
            size: 18,
          ),
          items: pageSizeOptions.map((s) {
            return DropdownMenuItem<int>(
              value: s,
              child: Text(
                '$s',
                style: AppTextStyles.tableCell(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCoffee,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != pageSize) {
              onPageSizeChanged(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
    bool isTrailingIcon = false,
    bool isCompact = false,
  }) {
    final textColor = isEnabled ? AppColors.darkCoffee : AppColors.textSecondary.withValues(alpha: 0.4);
    final borderColor = isEnabled ? AppColors.latteBeige : AppColors.latteBeige.withValues(alpha: 0.4);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailingIcon) ...[
              Icon(icon, size: 16, color: textColor),
              if (!isCompact) const SizedBox(width: 4),
            ],
            if (!isCompact)
              Text(
                label,
                style: AppTextStyles.buttonSmall(
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            if (isTrailingIcon) ...[
              if (!isCompact) const SizedBox(width: 4),
              Icon(icon, size: 16, color: textColor),
            ],
          ],
        ),
      ),
    );
  }
}
