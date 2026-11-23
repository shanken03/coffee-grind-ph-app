import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_animations.dart';
import '../../models/restock_request_model.dart';
import '../../providers/branch_session_provider.dart';
import '../../providers/restock_provider.dart';
import '../../providers/inventory_provider.dart';
import 'widgets/create_restock_dialog.dart';
import 'widgets/pagination_controls.dart';

/// Helper model to track pagination state per tab independently.
class TabPaginationState {
  int currentPage = 1;
  int pageSize = 10;

  void setPage(int page) {
    currentPage = page;
  }

  void setPageSize(int size) {
    pageSize = size;
    currentPage = 1; // Always return to page 1 when page size changes
  }

  void resetPage() {
    currentPage = 1;
  }

  int totalPages(int totalItems) {
    if (totalItems <= 0) return 1;
    return (totalItems / pageSize).ceil();
  }

  int getClampedPage(int totalItems) {
    final maxPage = totalPages(totalItems);
    if (currentPage > maxPage) {
      currentPage = maxPage;
    }
    if (currentPage < 1) {
      currentPage = 1;
    }
    return currentPage;
  }

  List<T> getPagedItems<T>(List<T> allItems) {
    if (allItems.isEmpty) return const [];
    final safePage = getClampedPage(allItems.length);
    final startIndex = (safePage - 1) * pageSize;
    return allItems.skip(startIndex).take(pageSize).toList();
  }
}

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _inventoryFilter = 'All';

  // Independent pagination states for each tab
  final TabPaginationState _activePagination = TabPaginationState();
  final TabPaginationState _inventoryPagination = TabPaginationState();
  final TabPaginationState _historyPagination = TabPaginationState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      // Reset all tabs to page 1 whenever search query changes
      _activePagination.resetPage();
      _inventoryPagination.resetPage();
      _historyPagination.resetPage();
    });
  }

  void _onStatusFilterChanged(String st) {
    setState(() {
      _statusFilter = st;
      // Reset request tabs to page 1 whenever status filter changes
      _activePagination.resetPage();
      _historyPagination.resetPage();
    });
  }

  void _onInventoryFilterChanged(String f) {
    setState(() {
      _inventoryFilter = f;
      _inventoryPagination.resetPage();
    });
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _inventoryFilter = 'All';
      _activePagination.resetPage();
      _inventoryPagination.resetPage();
      _historyPagination.resetPage();
    });
  }

  Color _getStatusColor(RestockStatus status) {
    switch (status) {
      case RestockStatus.pending:
        return AppColors.statusPending;
      case RestockStatus.approved:
        return AppColors.statusApproved;
      case RestockStatus.rejected:
        return AppColors.statusRejected;
      case RestockStatus.received:
        return AppColors.statusReceived;
    }
  }

  List<RestockRequestModel> _filterRequests(List<RestockRequestModel> list) {
    return list.where((r) {
      final matchesSearch = _searchQuery.isEmpty ||
          r.itemType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (r.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesStatus =
          _statusFilter == 'All' || r.status.label.toLowerCase() == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<InventoryItemModel> _filterInventory(List<InventoryItemModel> list) {
    return list.where((i) {
      final matchesSearch = _searchQuery.isEmpty ||
          i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          i.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStock = _inventoryFilter == 'All' ||
          (_inventoryFilter == 'Low Stock' && i.isLowStock) ||
          (_inventoryFilter == 'In Stock' && !i.isLowStock);

      return matchesSearch && matchesStock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();
    final restockProvider = context.watch<RestockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Restocking & Inventory',
              style: AppTextStyles.pageTitle(
                color: AppColors.darkCoffee,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (session.currentBranchName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${session.currentBranchName} Branch',
                style: AppTextStyles.caption(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const CreateRestockDialog(),
                );
              },
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.surfaceWhite,
              ),
              label: Text(
                'New Request',
                style: AppTextStyles.buttonSmall(
                  color: AppColors.surfaceWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCoffee,
                foregroundColor: AppColors.surfaceWhite,
                elevation: 2,
                shadowColor: const Color(0x332E1C14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.darkCoffee,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.darkCoffee,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.navLabel(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTextStyles.navLabel(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Active'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            '${restockProvider.activeRequests.length}',
                            style: AppTextStyles.badge(fontSize: 10, color: AppColors.darkCoffee),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Inventory'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            '${inventoryProvider.items.length}',
                            style: AppTextStyles.badge(fontSize: 10, color: AppColors.darkCoffee),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('History'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            '${restockProvider.historyRequests.length}',
                            style: AppTextStyles.badge(fontSize: 10, color: AppColors.darkCoffee),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Search & Filter Bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    maxLength: 26,
                    inputFormatters: [LengthLimitingTextInputFormatter(26)],
                    style: AppTextStyles.inputField(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _tabController.index == 1
                          ? 'Search inventory items or category...'
                          : 'Search requests or category...',
                      hintStyle: AppTextStyles.inputHint(fontSize: 13),
                      counterText: '',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.darkCoffee, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Filter: ',
                        style: AppTextStyles.caption(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: (_tabController.index == 1
                                    ? ['All', 'Low Stock', 'In Stock']
                                    : ['All', 'Pending', 'Approved', 'Rejected', 'Received'])
                                .map((st) {
                              final isSelected = (_tabController.index == 1)
                                  ? (_inventoryFilter == st)
                                  : (_statusFilter == st);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    st,
                                    style: AppTextStyles.badge(
                                      fontSize: 12,
                                      color: isSelected ? AppColors.surfaceWhite : AppColors.darkCoffee,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.darkCoffee,
                                  backgroundColor: AppColors.warmCream,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.darkCoffee : AppColors.borderSubtle,
                                  ),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected) {
                                      if (_tabController.index == 1) {
                                        _onInventoryFilterChanged(st);
                                      } else {
                                        _onStatusFilterChanged(st);
                                      }
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views with Paged Lists and Built-In Independent Pagination Controls
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Active Requests (Paged)
                  _buildPagedRequestList(
                    allRequests: restockProvider.activeRequests,
                    paginationState: _activePagination,
                    isLoading: restockProvider.isLoading,
                    errorMessage: restockProvider.requestsErrorMessage,
                    tabTitle: 'Active Requests',
                    emptyMessage: 'No active restocking requests found.',
                    emptySubtitle: 'Tap "+ New Request" to submit a restock request to Owner Web.',
                  ),

                  // Tab 2: Branch Inventory Stock View (Paged)
                  _buildPagedInventoryList(
                    inventoryProvider: inventoryProvider,
                    paginationState: _inventoryPagination,
                  ),

                  // Tab 3: History Requests (Paged)
                  _buildPagedRequestList(
                    allRequests: restockProvider.historyRequests,
                    paginationState: _historyPagination,
                    isLoading: restockProvider.isLoading,
                    errorMessage: restockProvider.requestsErrorMessage,
                    tabTitle: 'History Requests',
                    emptyMessage: 'No restocking history records found.',
                    emptySubtitle: 'Completed, received, or rejected requests will display here.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagedRequestList({
    required List<RestockRequestModel> allRequests,
    required TabPaginationState paginationState,
    required bool isLoading,
    String? errorMessage,
    required String tabTitle,
    required String emptyMessage,
    required String emptySubtitle,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.darkCoffee));
    }

    if (errorMessage != null && allRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppColors.mutedRed,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to Load Requests',
                style: AppTextStyles.cardTitle(
                  fontSize: 16,
                  color: AppColors.mutedRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                errorMessage,
                style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 1. Check if entirely empty in database
    if (allRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              emptySubtitle,
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 2. Apply search & status filters to complete dataset
    final filtered = _filterRequests(allRequests);

    // 3. Check if search/filter returned no results
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching records found.',
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search query or status filter.',
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: Text('Clear Filters', style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCoffee,
                side: const BorderSide(color: AppColors.borderSubtle),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Client-side pagination slicing
    final pagedRequests = paginationState.getPagedItems(filtered);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedRequests.length,
            itemBuilder: (context, index) {
              final req = pagedRequests[index];
              final statusColor = _getStatusColor(req.status);
              final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(req.createdAt);

              return AppFadeSlideScale(
                key: ValueKey<String>('req_${req.id}'),
                duration: Duration(
                  milliseconds: 240 + (index.clamp(0, 6) * 30),
                ),
                beginOffset: const Offset(0, 14),
                beginScale: 0.98,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Icon, Item Name, Category, Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.warmCream,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Icon(
                                    req.category.toLowerCase().contains('ingred')
                                        ? Icons.coffee_rounded
                                        : Icons.takeout_dining_rounded,
                                    color: AppColors.darkCoffee,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        req.itemType,
                                        style: AppTextStyles.cardTitle(
                                          fontSize: 16,
                                          color: AppColors.darkCoffee,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warmCream,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.borderSubtle),
                                        ),
                                        child: Text(
                                          req.category,
                                          style: AppTextStyles.badge(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  req.status == RestockStatus.pending
                                      ? Icons.schedule_rounded
                                      : (req.status == RestockStatus.approved
                                          ? Icons.thumb_up_alt_rounded
                                          : (req.status == RestockStatus.received
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded)),
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  req.status.label.toUpperCase(),
                                  style: AppTextStyles.badge(
                                    fontSize: 11,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Requested Quantity Highlight Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.warmCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Requested: ',
                                  style: AppTextStyles.caption(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${req.quantity} ${req.unit}',
                                  style: AppTextStyles.statNumber(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.darkCoffee,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Text(
                                req.id,
                                style: AppTextStyles.caption(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (req.note != null && req.note!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.note!,
                                  style: AppTextStyles.caption(color: AppColors.darkCoffee, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.borderSubtle, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  dateStr,
                                  style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  req.branchName,
                                  style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
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
              );
            },
          ),
        ),
        PaginationControls(
          currentPage: paginationState.getClampedPage(filtered.length),
          totalPages: paginationState.totalPages(filtered.length),
          totalItems: filtered.length,
          pageSize: paginationState.pageSize,
          onPageChanged: (newPage) => setState(() => paginationState.setPage(newPage)),
          onPageSizeChanged: (newSize) => setState(() => paginationState.setPageSize(newSize)),
          itemName: 'requests',
        ),
      ],
    );
  }

  Widget _buildPagedInventoryList({
    required InventoryProvider inventoryProvider,
    required TabPaginationState paginationState,
  }) {
    if (inventoryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.darkCoffee));
    }

    final allItems = inventoryProvider.items;

    if (inventoryProvider.hasError && allItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppColors.mutedRed,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to Load Inventory',
                style: AppTextStyles.cardTitle(
                  fontSize: 16,
                  color: AppColors.mutedRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                inventoryProvider.errorMessage!,
                style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 1. Check if entirely empty in database
    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.widgets_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No inventory items found.',
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Master inventory items configured on Owner Web will display here.',
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // 2. Filter inventory by search query & stock status
    final filtered = _filterInventory(allItems);

    // 3. Check if search query matched nothing
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching records found.',
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No inventory items match your search or filter.',
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: Text('Clear Filters', style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCoffee,
                side: const BorderSide(color: AppColors.borderSubtle),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Client-side pagination slicing
    final pagedItems = paginationState.getPagedItems(filtered);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedItems.length,
            itemBuilder: (context, index) {
              final item = pagedItems[index];
              final double stockRatio = item.minStock > 0
                  ? (item.availableQuantity / (item.minStock * 2.0)).clamp(
                      0.0,
                      1.0,
                    )
                  : (item.availableQuantity > 0 ? 1.0 : 0.0);

              return AppFadeSlideScale(
                key: ValueKey<String>('inv_${item.id}'),
                duration: Duration(
                  milliseconds: 240 + (index.clamp(0, 6) * 30),
                ),
                beginOffset: const Offset(0, 14),
                beginScale: 0.98,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isLowStock
                        ? AppColors.amber.withValues(alpha: 0.5)
                        : AppColors.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.isLowStock
                              ? AppColors.amber.withValues(alpha: 0.12)
                              : AppColors.warmCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isLowStock
                                ? AppColors.amber.withValues(alpha: 0.3)
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Icon(
                          item.isLowStock
                              ? Icons.warning_amber_rounded
                              : (item.category.toLowerCase().contains('ingred')
                                  ? Icons.coffee_rounded
                                  : Icons.takeout_dining_rounded),
                          color: item.isLowStock ? AppColors.amber : AppColors.darkCoffee,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: AppTextStyles.cardTitle(
                                fontSize: 16,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warmCream,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: AppTextStyles.badge(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Min: ${item.minStock.toStringAsFixed(0)} ${item.unit}',
                                  style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AppAnimatedProgressBar(
                                value: stockRatio,
                                minHeight: 5,
                                backgroundColor: AppColors.containerMuted,
                                valueColor: item.isLowStock
                                    ? AppColors.amber
                                    : AppColors.forestGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.availableQuantity.toStringAsFixed(0)} ${item.unit}',
                            style: AppTextStyles.statNumber(
                              fontSize: 17,
                              color: item.isLowStock ? AppColors.amber : AppColors.forestGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.isLowStock
                                  ? AppColors.amber.withValues(alpha: 0.12)
                                  : AppColors.forestGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: item.isLowStock
                                    ? AppColors.amber.withValues(alpha: 0.3)
                                    : AppColors.forestGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              item.isLowStock ? 'LOW STOCK' : 'IN STOCK',
                              style: AppTextStyles.badge(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isLowStock ? AppColors.amber : AppColors.forestGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              );
            },
          ),
        ),
        PaginationControls(
          currentPage: paginationState.getClampedPage(filtered.length),
          totalPages: paginationState.totalPages(filtered.length),
          totalItems: filtered.length,
          pageSize: paginationState.pageSize,
          onPageChanged: (newPage) => setState(() => paginationState.setPage(newPage)),
          onPageSizeChanged: (newSize) => setState(() => paginationState.setPageSize(newSize)),
          itemName: 'items',
        ),
      ],
    );
  }
}
