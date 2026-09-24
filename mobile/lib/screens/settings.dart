import 'package:flutter/material.dart';

import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Settings, notifications, paywall, about — port of settings.js.
// ====================================================================

// ========================= SETTINGS / MORE =========================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _logout(BuildContext context) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Sign out?',
      body: 'You can sign back in anytime. Local data stays on this device.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (ok == true) {
      Store.instance.logout();
      if (context.mounted) go(context, '/home');
    }
  }

  void _deleteAccount(BuildContext context) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Delete account?',
      body: 'This permanently removes your account and all local data. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
      icon: Icons.delete_forever_outlined,
    );
    if (ok == true) {
      Store.instance.deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('More', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final me = st.currentUser();
          final org = st.currentOrg();
          final pro = st.isPro();
          final team = st.teamList();
          final member = me == null
              ? null
              : team.where((t) => t.email.toLowerCase() == me.email.toLowerCase()).firstOrNull;
          final roleLbl = member?.role ?? 'owner';
          final skuUsed = st.activeItems().length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // profile card
              SfCard(
                onTap: () => toastOk('Profile editor coming soon'),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    avatar(me?.name ?? '?', color: me?.color ?? 'av-a', size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me?.name ?? 'You',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          Text(me?.email ?? '',
                              style: const TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                    chip(roleLbl == 'owner' ? 'navy' : 'blue', roleLbl[0].toUpperCase()),
                  ],
                ),
              ),
              // plan upsell
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: InkWell(
                  onTap: () => go(context, '/paywall'),
                  borderRadius: BorderRadius.circular(R.lg),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [C.navy, C.navy2]),
                      borderRadius: BorderRadius.circular(R.lg),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: pro ? C.greenSoft : Colors.white,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                              pro ? Icons.workspace_premium_rounded : Icons.rocket_launch_outlined,
                              color: pro ? C.green : C.navy,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  pro
                                      ? (org?.plan == 'trial' ? 'Trial active' : 'Pro plan')
                                      : 'Free plan',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                              Text(
                                  pro
                                      ? '${org?.trialDays ?? 0} days left · everything unlocked'
                                      : '${100 - skuUsed} SKUs left · 1 location · no reports',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
              const Text('OPERATIONS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              const SizedBox(height: 8),
              SfCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    _link(context, Icons.location_on_outlined, 'Locations', 'Where your stock lives', '/locations'),
                    const Divider(height: 20),
                    _link(context, Icons.swap_horiz_rounded, 'Transfer stock', 'Move items between locations', '/transfer'),
                    const Divider(height: 20),
                    _link(context, Icons.rule_outlined, 'Cycle counts', 'Verify on-hand numbers', '/counts'),
                    const Divider(height: 20),
                    _link(context, Icons.warning_amber_rounded, 'Low stock', '${st.lowItems().length} items need attention', '/lowstock'),
                    if (st.can('manageSuppliers')) ...[
                      const Divider(height: 20),
                      _link(context, Icons.storefront_outlined, 'Suppliers', 'Vendors & brands you buy from', '/suppliers'),
                    ],
                    if (st.can('manageTeam')) ...[
                      const Divider(height: 20),
                      _link(context, Icons.group_outlined, 'Team', 'Invite & manage teammates', '/team'),
                    ],
                    const Divider(height: 20),
                    _link(context, Icons.bar_chart_rounded, 'Reports', 'Valuation, movements & more', '/reports'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('PREFERENCES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              const SizedBox(height: 8),
              SfCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    _link(context, Icons.notifications_outlined, 'Notifications', 'Choose what you’re alerted about', '/notifprefs'),
                    const Divider(height: 20),
                    _link(context, Icons.info_outline_rounded, 'About', 'StockFlow, version & licenses', '/about'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SfCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _logout(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: C.red),
                            SizedBox(width: 12),
                            Text('Sign out', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: C.red)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    InkWell(
                      onTap: () => _deleteAccount(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_outlined, size: 18, color: C.muted),
                            SizedBox(width: 12),
                            Text('Delete account', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: C.muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _link(BuildContext context, IconData ic, String title, String sub, String path) {
    return InkWell(
      onTap: () => go(context, path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            Icon(ic, size: 19, color: C.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.muted.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// ========================= NOTIF PREFS =========================
class NotifPrefsScreen extends StatefulWidget {
  const NotifPrefsScreen({super.key});
  @override
  State<NotifPrefsScreen> createState() => _NotifPrefsScreenState();
}

class _NotifPrefsScreenState extends State<NotifPrefsScreen> {
  void _pref(String k, dynamic v) => Store.instance.setPref(k, v);

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final p = st.state.prefs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Section(
                title: 'WHAT YOU GET NOTIFIED ABOUT',
                padding: EdgeInsets.zero,
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      SwitchRow(
                        label: 'Low stock',
                        sub: 'Items falling below their reorder point',
                        checked: p.lowStock,
                        onChanged: (v) => _pref('lowStock', v),
                      ),
                      SwitchRow(
                        label: 'Purchase order updates',
                        sub: 'Receipts, sends and cancellations',
                        checked: p.poUpdates,
                        onChanged: (v) => _pref('poUpdates', v),
                      ),
                      SwitchRow(
                        label: 'Cycle counts',
                        sub: 'When a count is submitted or completed',
                        checked: p.counts,
                        onChanged: (v) => _pref('counts', v),
                      ),
                      SwitchRow(
                        label: 'Invites',
                        sub: 'New teammates joining',
                        checked: p.invites,
                        onChanged: (v) => _pref('invites', v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Section(
                title: 'QUIET HOURS',
                padding: EdgeInsets.zero,
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      SwitchRow(
                        label: 'Quiet hours',
                        sub: 'Mute notifications overnight',
                        checked: p.quietOn,
                        onChanged: (v) => _pref('quietOn', v),
                      ),
                      if (p.quietOn) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('From',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(p.quietFrom,
                                      style: const TextStyle(fontSize: 13, color: C.muted, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 16, color: C.muted),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('To',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(p.quietTo,
                                      style: const TextStyle(fontSize: 13, color: C.muted, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Section(
                title: 'BEHAVIOR',
                padding: EdgeInsets.zero,
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      SwitchRow(
                        label: 'Haptic feedback',
                        sub: 'Tiny buzzes on scans & actions',
                        checked: p.haptics,
                        onChanged: (v) => _pref('haptics', v),
                      ),
                      const Divider(height: 20),
                      SwitchRow(
                        label: 'Sounds',
                        checked: p.sounds,
                        onChanged: (v) => _pref('sounds', v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ========================= PAYWALL =========================
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final org = st.currentOrg();
    final pro = st.isPro();
    return Scaffold(
      backgroundColor: C.navy,
      appBar: AppBar(
        backgroundColor: C.navy,
        foregroundColor: Colors.white,
        title: const Text('StockFlow Pro', style: TextStyle(color: Colors.white)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text('Power up your inventory ops.',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 6),
              const Text('Everything you need to run stock like a pro — one flat price.',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 22),
              _feat(Icons.workspace_premium_outlined, 'Unlimited SKUs', 'No 100-item cap'),
              _feat(Icons.location_on_outlined, 'Unlimited locations', 'All your storage spots'),
              _feat(Icons.group_outlined, 'More team seats', 'Beyond the free 2'),
              _feat(Icons.bar_chart_rounded, 'Advanced reports', 'Movements & top movers with CSV/PDF export'),
              _feat(Icons.inventory_2_outlined, 'Bulk import', 'Bring your whole catalog at once'),
              _feat(Icons.support_agent_rounded, 'Priority support', 'Real humans, quick replies'),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(R.lg),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pro plan',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              Text('Billed monthly · cancel anytime',
                                  style: TextStyle(fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        const Text('\$9',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                        Text(' /mo', style: TextStyle(fontSize: 13, color: C.muted)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.navy),
                        onPressed: () {
                          if (pro) {
                            toastOk('You are already on Pro');
                            return;
                          }
                          Store.instance.upgradePlan();
                          toastOk('Pro plan activated');
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                        label: Text(pro ? 'You’re on Pro' : (org?.plan == 'trial' ? 'Start trial → Pro' : 'Start Pro')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _feat(IconData ic, String t, String s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(ic, size: 19, color: C.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(s, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= ABOUT =========================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('About', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('StockFlow',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text('stock on hand, everywhere',
                style: TextStyle(fontSize: 13, color: C.muted)),
          ),
          const SizedBox(height: 22),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _row('Version', '1.0.0 · native build'),
                const Divider(height: 20),
                _row('Platform', 'Android (Flutter)'),
                const Divider(height: 20),
                _row('Offline-first', 'Works without a connection'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'StockFlow was built as a native port of the StockFlow inventory web app. All data lives on this device.',
            style: TextStyle(fontSize: 13, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _row('Made with', 'Flutter · Dart'),
                const Divider(height: 20),
                _row('Icons', 'Material Icons'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 13.5, color: C.muted)),
          Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}