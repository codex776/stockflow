import 'package:flutter/material.dart';

import '../theme.dart';
import 'home.dart';
import 'items.dart';
import 'orders.dart';
import 'scan.dart';
import 'stock.dart';

/// Global tab controller — tab-anchor routes call [switchTab].
final ValueNotifier<int> shellTab = ValueNotifier(0);
void switchTab(int i) => shellTab.value = i;

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    ItemsScreen(),
    ScanScreen(),
    StockScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: shellTab,
        builder: (context, tab, _) => IndexedStack(index: tab, children: _pages),
      ),
      bottomNavigationBar: const SfTabBar(),
    );
  }
}

class SfTabBar extends StatelessWidget {
  const SfTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, tab, _) {
        return Container(
          height: tabbarH,
          decoration: const BoxDecoration(
            color: C.surface,
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              _tab(0, Icons.home_rounded, 'Home', tab),
              _tab(1, Icons.inventory_2_rounded, 'Items', tab),
              _scanButton(tab),
              _tab(3, Icons.swap_horiz_rounded, 'Stock', tab),
              _tab(4, Icons.shopping_cart_outlined, 'Orders', tab),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(int i, IconData ic, String label, int current) {
    final active = i == current;
    return Expanded(
      child: InkWell(
        onTap: () => switchTab(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, size: 22, color: active ? C.blueD : C.muted),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? C.blueD : C.muted)),
          ],
        ),
      ),
    );
  }

  Widget _scanButton(int current) {
    final active = current == 2;
    return Expanded(
      child: InkWell(
        onTap: () => switchTab(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [C.blue, C.navy2],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: C.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: C.blue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 3),
            Text('Scan',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? C.blueD : C.muted)),
          ],
        ),
      ),
    );
  }
}