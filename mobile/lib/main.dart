import 'package:flutter/material.dart';

import 'screens/auth.dart';
import 'screens/counts.dart';
import 'screens/home.dart';
import 'screens/items.dart';
import 'screens/orders.dart';
import 'screens/partners.dart';
import 'screens/reports.dart';
import 'screens/scan.dart';
import 'screens/settings.dart';
import 'screens/shell.dart';
import 'screens/stock.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.ensureReady();
  runApp(const SfApp());
}

class SfApp extends StatelessWidget {
  const SfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockFlow',
      debugShowCheckedModeBanner: false,
      theme: sfTheme(),
      home: const RootGate(),
    );
  }
}

// -------------------------------------------------------------------
// Session gating — mirrors app.js renderRoute guards.
// -------------------------------------------------------------------
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    setToastContext(context);
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final st = Store.instance.state;
        if (st.firstLaunch) return const SplashScreen();
        if (!st.session.authed) return const AuthScreen();
        if (!st.session.hasOrg) return const OrgScreen();
        return const AppShell();
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Store.instance.boot());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.inventory_2_rounded, size: 38, color: C.navy),
            ),
            const SizedBox(height: 16),
            Text('StockFlow',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text('stock on hand, everywhere',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 36),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// Route registry — mirrors app.js ROUTES table (35 routes).
// -------------------------------------------------------------------
Map<String, String> _parseQuery(String raw) {
  final qs = <String, String>{};
  final i = raw.indexOf('?');
  if (i < 0) return qs;
  final body = raw.substring(i + 1);
  for (final kv in body.split('&')) {
    if (kv.isEmpty) continue;
    final eq = kv.indexOf('=');
    if (eq < 0) {
      qs[kv] = '';
    } else {
      qs[kv.substring(0, eq)] = Uri.decodeComponent(kv.substring(eq + 1));
    }
  }
  return qs;
}

void go(BuildContext context, String path, {bool replace = false}) {
  final raw = path.replaceFirst(RegExp(r'^#'), '');
  final route = raw.split('?').first;
  final qs = _parseQuery(raw);

  Widget? w = switch (route) {
    '/home' => const HomeScreen(),
    '/items' => const ItemsScreen(),
    '/items/new' => ItemNewScreen(initBarcode: qs['barcode']),
    '/scan' => () {
        setScanMode(qs['mode'] ?? 'lookup');
        return const ScanScreen();
      }(),
    '/stock' => const StockScreen(),
    '/orders' => const OrdersScreen(),
    '/orders/new' => OrderNewScreen(initBarcode: qs['barcode']),
    '/locations' => const LocationsScreen(),
    '/transfer' => TransferScreen(itemId: qs['item'], fromId: qs['from']),
    '/lowstock' => const LowStockScreen(),
    '/suppliers' => const SuppliersScreen(),
    '/suppliers/new' => const SupplierNewScreen(),
    '/team' => const TeamScreen(),
    '/reports' => ReportsScreen(
        rep: qs['r'], days: qs['days'], type: qs['type']),
    '/settings' => const SettingsScreen(),
    '/notifprefs' => const NotifPrefsScreen(),
    '/paywall' => const PaywallScreen(),
    '/about' => const AboutScreen(),
    '/counts' => const CountsScreen(),
    '/counts/new' => CountNewScreen(initLoc: qs['loc']),
    '/notifications' => const NotificationsScreen(),
    _ => null,
  };

  if (w == null) {
    final seg = route.split('/').where((s) => s.isNotEmpty).toList();
    if (seg.length == 2) {
      final id = seg[1];
      w = switch (seg[0]) {
        'items' => ItemDetailScreen(itemId: id),
        'orders' => OrderDetailScreen(poId: id),
        'locations' => LocationDetailScreen(locationId: id),
        'suppliers' => SupplierDetailScreen(supplierId: id),
        'counts' => CountDetailScreen(countId: id),
        _ => null,
      };
    } else if (seg.length == 3) {
      final id = seg[1];
      w = switch ('${seg[0]}/${seg[2]}') {
        'items/edit' => ItemEditScreen(itemId: id),
        'orders/edit' => OrderEditScreen(poId: id),
        'orders/receive' => OrderReceiveScreen(poId: id),
        'counts/run' => CountRunScreen(countId: id),
        'counts/review' => CountReviewScreen(countId: id),
        _ => null,
      };
    }
  }

  w ??= const HomeScreen();

  final tab = _tabOf(w);
  if (tab != null) {
    switchTab(tab);
  } else if (replace) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => w!));
  } else {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => w!));
  }
}

int? _tabOf(Widget w) {
  if (w is HomeScreen) return 0;
  if (w is ItemsScreen) return 1;
  if (w is ScanScreen) return 2;
  if (w is StockScreen) return 3;
  if (w is OrdersScreen) return 4;
  return null;
}