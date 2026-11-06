import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/restock_request_model.dart';
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

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
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
      return _searchQuery.isEmpty ||
          i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          i.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final restockProvider = context.watch<RestockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restocking & Inventory',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppColors.latteBeige, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.forestGreen,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.forestGreen,
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
                    child: Text('Active (${restockProvider.activeRequests.length})'),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Inventory (${inventoryProvider.items.length})'),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('History (${restockProvider.historyRequests.length})'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const CreateRestockDialog(),
          );
        },
        backgroundColor: AppColors.darkCoffee,
        icon: const Icon(Icons.add_rounded, color: AppColors.surfaceWhite),
        label: Text(
          'New Request',
          style: AppTextStyles.button(color: AppColors.surfaceWhite),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Search & Status Filter Bar
            Container(
              color: AppColors.surfaceWhite,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: AppTextStyles.inputField(),
                    decoration: InputDecoration(
                      hintText: 'Search items or category...',
                      hintStyle: AppTextStyles.inputHint(),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.darkCoffee),
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
                        'Status: ',
                        style: AppTextStyles.caption(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Pending', 'Approved', 'Rejected', 'Received'].map((st) {
                              final isSelected = _statusFilter == st;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    st,
                                    style: AppTextStyles.badge(
                                      fontSize: 12,
                                      color: isSelected ? AppColors.surfaceWhite : AppColors.textSecondary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.forestGreen,
                                  backgroundColor: AppColors.surfaceWhite,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.forestGreen : AppColors.latteBeige,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) _onStatusFilterChanged(st);
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

            const Divider(height: 1, color: AppColors.latteBeige),

            // Tab Views with Paged Lists
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
      bottomNavigationBar: _buildActivePaginationBar(restockProvider, inventoryProvider),
    );
  }

  /// Returns the pagination bar corresponding to the currently active tab
  Widget? _buildActivePaginationBar(
    RestockProvider restockProvider,
    InventoryProvider inventoryProvider,
  ) {
    if (_tabController.index == 0) {
      if (restockProvider.isLoading) return null;
      final filtered = _filterRequests(restockProvider.activeRequests);
      if (filtered.isEmpty) return null;
      return PaginationControls(
        currentPage: _activePagination.getClampedPage(filtered.length),
        totalPages: _activePagination.totalPages(filtered.length),
        totalItems: filtered.length,
        pageSize: _activePagination.pageSize,
        onPageChanged: (newPage) => setState(() => _activePagination.setPage(newPage)),
        onPageSizeChanged: (newSize) => setState(() => _activePagination.setPageSize(newSize)),
        itemName: 'requests',
      );
    } else if (_tabController.index == 1) {
      if (inventoryProvider.isLoading) return null;
      final filtered = _filterInventory(inventoryProvider.items);
      if (filtered.isEmpty) return null;
      return PaginationControls(
        currentPage: _inventoryPagination.getClampedPage(filtered.length),
        totalPages: _inventoryPagination.totalPages(filtered.length),
        totalItems: filtered.length,
        pageSize: _inventoryPagination.pageSize,
        onPageChanged: (newPage) => setState(() => _inventoryPagination.setPage(newPage)),
        onPageSizeChanged: (newSize) => setState(() => _inventoryPagination.setPageSize(newSize)),
        itemName: 'items',
      );
    } else {
      if (restockProvider.isLoading) return null;
      final filtered = _filterRequests(restockProvider.historyRequests);
      if (filtered.isEmpty) return null;
      return PaginationControls(
        currentPage: _historyPagination.getClampedPage(filtered.length),
        totalPages: _historyPagination.totalPages(filtered.length),
        totalItems: filtered.length,
        pageSize: _historyPagination.pageSize,
        onPageChanged: (newPage) => setState(() => _historyPagination.setPage(newPage)),
        onPageSizeChanged: (newSize) => setState(() => _historyPagination.setPageSize(newSize)),
        itemName: 'records',
      );
    }
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
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No records found.',
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
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
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
                side: const BorderSide(color: AppColors.latteBeige),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Client-side pagination slicing
    final pagedRequests = paginationState.getPagedItems(filtered);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: pagedRequests.length,
      itemBuilder: (context, index) {
        final req = pagedRequests[index];
        final statusColor = _getStatusColor(req.status);
        final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(req.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.latteBeige, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.darkCoffee.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            req.category.contains('Ingredients')
                                ? Icons.kitchen_rounded
                                : Icons.inventory_rounded,
                            color: AppColors.darkCoffee,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.itemType,
                              style: AppTextStyles.cardTitle(
                                fontSize: 16,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                            Text(
                              req.category,
                              style: AppTextStyles.caption(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        req.status.label,
                        style: AppTextStyles.badge(
                          fontSize: 12,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.latteBeige, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Requested Qty: ${req.quantity} ${req.unit}',
                        style: AppTextStyles.tableCell(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                      Text(
                        req.id,
                        style: AppTextStyles.caption(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                if (req.note != null && req.note!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Note: ${req.note}',
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],

                const Divider(height: 20, color: AppColors.latteBeige),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      req.branchName,
                      style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            Icon(
              Icons.widgets_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No records found.',
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

    // 2. Filter inventory by search query
    final filtered = _filterInventory(allItems);

    // 3. Check if search query matched nothing
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching records found.',
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No inventory items match your search query.',
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: Text('Clear Search', style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCoffee,
                side: const BorderSide(color: AppColors.latteBeige),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Client-side pagination slicing
    final pagedItems = paginationState.getPagedItems(filtered);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: pagedItems.length,
      itemBuilder: (context, index) {
        final item = pagedItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.latteBeige, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: item.isLowStock
                  ? AppColors.amber.withValues(alpha: 0.15)
                  : AppColors.darkCoffee.withValues(alpha: 0.08),
              child: Icon(
                item.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_rounded,
                color: item.isLowStock ? AppColors.amber : AppColors.darkCoffee,
              ),
            ),
            title: Text(
              item.name,
              style: AppTextStyles.cardTitle(fontSize: 15, color: AppColors.darkCoffee),
            ),
            subtitle: Text(
              'Category: ${item.category} • Min Stock: ${item.minStock.toStringAsFixed(0)} ${item.unit}',
              style: AppTextStyles.subtitle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.availableQuantity.toStringAsFixed(0)} ${item.unit}',
                  style: AppTextStyles.statNumber(
                    fontSize: 16,
                    color: item.isLowStock ? AppColors.amber : AppColors.darkCoffee,
                  ),
                ),
                if (item.isLowStock)
                  Text(
                    'LOW STOCK',
                    style: AppTextStyles.badge(
                      fontSize: 10,
                      color: AppColors.amber,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
