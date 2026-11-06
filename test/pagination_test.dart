import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_grind_ph/features/restock/widgets/pagination_controls.dart';
import 'package:coffee_grind_ph/features/restock/restock_screen.dart';

void main() {
  group('TabPaginationState Unit Tests', () {
    test('Calculates total pages correctly', () {
      final state = TabPaginationState();
      state.pageSize = 10;

      expect(state.totalPages(0), 1);
      expect(state.totalPages(5), 1);
      expect(state.totalPages(10), 1);
      expect(state.totalPages(11), 2);
      expect(state.totalPages(45), 5);
    });

    test('Slices items correctly for page 1 and page 2', () {
      final state = TabPaginationState();
      state.pageSize = 10;
      final dummyItems = List.generate(25, (i) => 'Item $i');

      final page1 = state.getPagedItems(dummyItems);
      expect(page1.length, 10);
      expect(page1.first, 'Item 0');
      expect(page1.last, 'Item 9');

      state.setPage(2);
      final page2 = state.getPagedItems(dummyItems);
      expect(page2.length, 10);
      expect(page2.first, 'Item 10');
      expect(page2.last, 'Item 19');

      state.setPage(3);
      final page3 = state.getPagedItems(dummyItems);
      expect(page3.length, 5);
      expect(page3.first, 'Item 20');
      expect(page3.last, 'Item 24');
    });

    test('Setting page size resets to page 1', () {
      final state = TabPaginationState();
      state.pageSize = 10;
      state.setPage(3);
      expect(state.currentPage, 3);

      state.setPageSize(20);
      expect(state.pageSize, 20);
      expect(state.currentPage, 1);
    });

    test('Clamps safely when items shrink or delete', () {
      final state = TabPaginationState();
      state.pageSize = 10;
      state.setPage(5);

      // Total items reduced to 15 (only 2 pages now)
      expect(state.getClampedPage(15), 2);
      expect(state.currentPage, 2);

      // Total items reduced to 0
      expect(state.getClampedPage(0), 1);
      expect(state.currentPage, 1);
    });
  });

  group('PaginationControls Widget Tests', () {
    testWidgets('Renders mobile layout on narrow screens', (WidgetTester tester) async {
      int selectedPage = 1;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationControls(
              currentPage: 1,
              totalPages: 5,
              totalItems: 45,
              pageSize: 10,
              onPageChanged: (p) => selectedPage = p,
              onPageSizeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Showing 1–10 of 45 items'), findsOneWidget);
      expect(find.text('Page 1 of 5'), findsOneWidget);

      // On mobile, navigation uses chevron icons
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Next button click triggers page 2
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      expect(selectedPage, 2);
    });

    testWidgets('Renders tablet layout on wide screens', (WidgetTester tester) async {
      int selectedPage = 1;

      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationControls(
              currentPage: 2,
              totalPages: 5,
              totalItems: 45,
              pageSize: 10,
              onPageChanged: (p) => selectedPage = p,
              onPageSizeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Showing 11–20 of 45 items'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Page numbers are rendered on tablet
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Tap on page 4
      await tester.tap(find.text('4'));
      expect(selectedPage, 4);
    });

    testWidgets('Disables Prev on page 1 and Next on last page', (WidgetTester tester) async {
      int pageCall = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationControls(
              currentPage: 1,
              totalPages: 1,
              totalItems: 5,
              pageSize: 10,
              onPageChanged: (p) => pageCall = p,
              onPageSizeChanged: (_) {},
            ),
          ),
        ),
      );

      // Tapping disabled Next or Prev icon should not invoke callback
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      expect(pageCall, 0);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      expect(pageCall, 0);
    });
  });
}
