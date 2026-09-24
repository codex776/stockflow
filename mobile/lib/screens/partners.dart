import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Suppliers + team — port of partners.js.
// ====================================================================

const _roleMeta = [
  (value: 'owner', label: 'Owner', desc: 'Full control — billing, locations, data', icon: Icons.admin_panel_settings_outlined),
  (value: 'manager', label: 'Manager', desc: 'Runs operations — items, orders, counts', icon: Icons.manage_accounts_outlined),
  (value: 'staff', label: 'Staff', desc: 'Scans, receives, transfers and counts', icon: Icons.badge_outlined),
];

String roleLabel(String role) {
  for (final r in _roleMeta) {
    if (r.value == role) return r.label;
  }
  return role;
}

String roleDesc(String role) {
  for (final r in _roleMeta) {
    if (r.value == role) return r.desc;
  }
  return '';
}

// ========================= SUPPLIERS LIST =========================
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Suppliers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: C.ink),
            onPressed: () => go(context, '/suppliers/new'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final st = Store.instance;
          final sups = st.suppliers();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (sups.isEmpty)
                emptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No suppliers yet',
                  body: 'Add the brands and vendors you buy from, then create purchase orders against them.',
                  ctaLabel: 'Add supplier',
                  onCta: () => go(context, '/suppliers/new'),
                )
              else
                for (final s in sups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _supplierCard(context, s, st),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _supplierCard(BuildContext context, Supplier s, Store st) {
    final openPOs = st.posList().where((p) => p.supplierId == s.id && ['draft', 'sent', 'partial'].contains(p.status)).length;
    final items = st.activeItems().where((i) => i.supplierId == s.id).length;
    return RowCard(
      left: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(12)),
        child: Text(
            s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.blueD)),
      ),
      title: s.name,
      sub: '$openPOs open order${openPOs == 1 ? '' : 's'} · $items item${items == 1 ? '' : 's'}',
      trailing: openPOs > 0 ? chip('amber', '$openPOs open') : null,
      onTap: () => go(context, '/suppliers/${s.id}'),
    );
  }
}

// ========================= SUPPLIER NEW =========================
class SupplierNewScreen extends StatefulWidget {
  const SupplierNewScreen({super.key});
  @override
  State<SupplierNewScreen> createState() => _SupplierNewScreenState();
}

class _SupplierNewScreenState extends State<SupplierNewScreen> {
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final leadCtrl = TextEditingController();
  final termsCtrl = TextEditingController();
  String err = '';

  @override
  void dispose() {
    for (final c in [nameCtrl, contactCtrl, emailCtrl, phoneCtrl, addressCtrl, leadCtrl, termsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => err = 'Supplier name is required');
      return;
    }
    try {
      final s = Store.instance.addSupplier(Supplier()
        ..name = name
        ..contact = contactCtrl.text.trim()
        ..email = emailCtrl.text.trim()
        ..phone = phoneCtrl.text.trim()
        ..address = addressCtrl.text.trim()
        ..leadTimeDays = int.tryParse(leadCtrl.text.trim()) ?? 0
        ..terms = termsCtrl.text.trim());
      toastOk('Supplier added');
      go(context, '/suppliers/${s.id}', replace: true);
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('New supplier', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton(onPressed: _save, child: const Text('Add supplier')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Labeled(
            label: 'Supplier name *',
            child: TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Kilimanjaro Coffee'),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Contact person',
            child: TextField(
              controller: contactCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Who to talk to'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Labeled(
                  label: 'Email',
                  child: TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email address'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Labeled(
                  label: 'Phone',
                  child: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Phone'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Address',
            child: TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(hintText: 'Street, city'),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Lead time (days)',
            hint: 'Shown on orders from this supplier',
            child: TextField(
              controller: leadCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'e.g. 7'),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Terms & notes',
            child: TextField(
              controller: termsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Payment terms, delivery notes…'),
            ),
          ),
          if (err.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
        ],
      ),
    );
  }
}

// ========================= SUPPLIER DETAIL =========================
class SupplierDetailScreen extends StatelessWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  Future<void> _edit(BuildContext context, Supplier s) async {
    final nameCtrl = TextEditingController(text: s.name);
    final contactCtrl = TextEditingController(text: s.contact);
    final emailCtrl = TextEditingController(text: s.email);
    final phoneCtrl = TextEditingController(text: s.phone);
    final addressCtrl = TextEditingController(text: s.address);
    final leadCtrl = TextEditingController(text: s.leadTimeDays == null || s.leadTimeDays == 0 ? '' : '${s.leadTimeDays}');
    final termsCtrl = TextEditingController(text: s.terms);
    String err = '';
    await openSheet<bool>(
      context: context,
      title: 'Edit supplier',
      build: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Labeled(label: 'Name', child: TextField(controller: nameCtrl)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Labeled(label: 'Contact', child: TextField(controller: contactCtrl))),
              const SizedBox(width: 10),
              Expanded(child: Labeled(label: 'Email', child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Labeled(label: 'Phone', child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone))),
              const SizedBox(width: 10),
              Expanded(child: Labeled(label: 'Lead (days)', child: TextField(controller: leadCtrl, keyboardType: TextInputType.number))),
            ],
          ),
          const SizedBox(height: 12),
          Labeled(label: 'Address', child: TextField(controller: addressCtrl)),
          const SizedBox(height: 12),
          Labeled(label: 'Terms', child: TextField(controller: termsCtrl, maxLines: 2)),
          if (err.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            try {
              Store.instance.updateSupplier(s.id, s
                ..name = nameCtrl.text.trim()
                ..contact = contactCtrl.text.trim()
                ..email = emailCtrl.text.trim()
                ..phone = phoneCtrl.text.trim()
                ..address = addressCtrl.text.trim()
                ..leadTimeDays = int.tryParse(leadCtrl.text.trim()) ?? 0
                ..terms = termsCtrl.text.trim());
              toastOk('Supplier updated');
              Navigator.pop(context, true);
            } catch (e) {
              toastErr(e.toString());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _archive(BuildContext context) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Archive this supplier?',
      body: 'Suppliers with open purchase orders cannot be archived.',
      confirmLabel: 'Archive',
      icon: Icons.archive_outlined,
    );
    if (ok != true) return;
    try {
      Store.instance.archiveSupplier(supplierId);
      toastOk('Supplier archived');
      if (context.mounted) go(context, '/suppliers', replace: true);
    } catch (e) {
      toastErr(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final s = st.supplierById(supplierId);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supplier')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Supplier not found',
          ctaLabel: 'Back',
          onCta: () => go(context, '/suppliers', replace: true),
        ),
      );
    }
    final items = st.activeItems().where((i) => i.supplierId == s.id).toList();
    final orderCount = st.posList().where((p) => p.supplierId == s.id).length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Supplier', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (st.can('manageSuppliers'))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: C.ink),
              onPressed: () => _edit(context, s),
            ),
          if (st.can('manageSuppliers'))
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: C.ink),
              onPressed: () => _archive(context),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                color: C.surface,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                          s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.blueD)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          if (s.contact.isNotEmpty)
                            const SizedBox(height: 2),
                          if (s.contact.isNotEmpty)
                            Text('Contact: ${s.contact}',
                                style: const TextStyle(fontSize: 12.5, color: C.muted)),
                          if (s.leadTimeDays != null && s.leadTimeDays! > 0)
                            Text('~${s.leadTimeDays} day lead time',
                                style: const TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$orderCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('orders', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              if (s.email.isNotEmpty || s.phone.isNotEmpty || s.address.isNotEmpty)
                Section(
                  title: 'CONTACT',
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: SfCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        if (s.email.isNotEmpty)
                          _copyRow(Icons.email_outlined, s.email, s.email),
                        if (s.phone.isNotEmpty)
                          _copyRow(Icons.phone_outlined, s.phone, s.phone),
                        if (s.address.isNotEmpty)
                          _copyRow(Icons.location_on_outlined, s.address, s.address),
                      ],
                    ),
                  ),
                ),
              if (s.terms.isNotEmpty)
                Section(
                  title: 'TERMS & NOTES',
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: SfCard(
                    child: Text(s.terms, style: const TextStyle(fontSize: 13.5, height: 1.45)),
                  ),
                ),
              Section(
                title: 'SUPPLIED ITEMS (${items.length})',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: items.isEmpty
                    ? const SfCard(
                        child: Text('No items set to this supplier.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              _itemRow(context, items[i]),
                            ],
                          ],
                        ),
                      ),
              ),
              Section(
                title: 'ORDERS',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (final p in st.posList().where((p) => p.supplierId == s.id)) ...[
                        InkWell(
                          onTap: () => go(context, '/orders/${p.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.number,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                                      Text('Created ${dShort(p.createdAt)}',
                                          style: const TextStyle(fontSize: 11.5, color: C.muted)),
                                    ],
                                  ),
                                ),
                                _poChip(p),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: C.muted),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _copyRow(IconData ic, String label, String copy) {
    return InkWell(
      onTap: () => copyText(copy),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(ic, size: 17, color: C.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
            const Icon(Icons.copy_rounded, size: 15, color: C.muted),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(BuildContext context, Item item) {
    final st = Store.instance;
    return InkWell(
      onTap: () => go(context, '/items/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            thumb(item, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(item.sku, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: C.muted)),
                ],
              ),
            ),
            Text('${num(st.totalOn(item.id))} ${item.unit}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ========================= TEAM =========================
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  Future<void> _invite(BuildContext context) async {
    final st = Store.instance;
    final emailCtrl = TextEditingController();
    var role = 'staff';
    String err = '';
    final added = await openSheet<bool>(
      context: context,
      title: 'Invite teammate',
      build: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Labeled(
            label: 'Email *',
            child: TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'teammate@company.com'),
            ),
          ),
          const SizedBox(height: 14),
          const Text('ROLE',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: role,
            onChanged: (v) => set(() => role = v ?? 'staff'),
            child: Column(
              children: [
                for (final r in _roleMeta)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(r.desc, style: const TextStyle(fontSize: 12, color: C.muted)),
                    value: r.value,
                  ),
              ],
            ),
          ),
          if (err.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty) {
                      set(() => err = 'Email is required');
                      return;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                      set(() => err = 'Enter a valid email');
                      return;
                    }
                    try {
                      st.inviteMember(email, role);
                      toastOk('Invite sent to $email');
                      Navigator.pop(ctx, true);
                    } catch (e) {
                      set(() => err = isLimitError(e)
                          ? 'Free plan is limited to 2 team seats. Upgrade to add more.'
                          : e.toString());
                    }
                  },
                  child: const Text('Invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (added == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _memberSheet(BuildContext context, TeamMember m) async {
    final st = Store.instance;
    final me = st.currentUser();
    final mine = m.email.toLowerCase() == (me?.email ?? '').toLowerCase();
    String err = '';
    await openSheet<void>(
      context: context,
      title: m.name,
      subtitle: m.email,
      build: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (st.can('manageTeam') && !mine) ...[
            const Text('ROLE',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: m.role,
              onChanged: (v) async {
                try {
                  st.setMemberRole(m.id, v ?? 'staff');
                  toastOk('Role updated to ${roleLabel(v ?? 'staff')}');
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  set(() => err = e.toString());
                }
              },
              child: Column(
                children: [
                  for (final r in _roleMeta)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      value: r.value,
                    ),
                ],
              ),
            ),
          ] else ...[
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roleLabel(m.role),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(roleDesc(m.role), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ],
              ),
            ),
          ],
          if (err.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
        ],
      ),
      actions: [
        if (st.can('manageTeam') && !mine)
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: C.red),
            onPressed: () async {
              final ok = await confirmSheet(
                context: context,
                title: 'Remove ${m.name}?',
                body: 'They will lose access to this workspace.',
                confirmLabel: 'Remove',
                danger: true,
                icon: Icons.person_remove_outlined,
              );
              if (ok == true) {
                try {
                  st.removeMember(m.id);
                  toastOk('${m.name} removed');
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  toastErr(e.toString());
                }
              }
            },
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Team', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (st.can('manageTeam'))
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: C.ink),
              onPressed: () => _invite(context),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final team = st.teamList();
          final me = st.currentUser();
          final org = st.currentOrg();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SfCard(
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.leaderboard_outlined, color: C.blueD, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite code',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Share ${org?.name ?? ''} with teammates',
                              style: const TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                    Text(org?.inviteCode ?? '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                    IconButton(
                      iconSize: 17,
                      icon: const Icon(Icons.copy_rounded, color: C.muted),
                      onPressed: () => copyText(org?.inviteCode ?? '', 'Invite code copied'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('TEAM (${team.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              const SizedBox(height: 10),
              for (final m in team)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RowCard(
                    left: avatar(m.name, color: m.color),
                    title: m.name +
                        (m.email.toLowerCase() == (me?.email ?? '').toLowerCase() ? ' (you)' : ''),
                    sub: '${m.email} · ${roleDesc(m.role)}',
                    trailing: chip(m.role == 'owner' ? 'navy' : 'blue', roleLabel(m.role)),
                    onTap: () => _memberSheet(context, m),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Widget _poChip(Po po) {
  final st = Store.instance;
  final s = st.poStatus(po);
  final label = switch (s) {
    'draft' => 'Draft',
    'sent' => 'Sent',
    'partial' => 'Partial',
    'received' => 'Received',
    _ => 'Cancelled',
  };
  final key = switch (s) {
    'draft' => 'navy',
    'sent' => 'blue',
    'partial' => 'amber',
    'received' => 'green',
    _ => 'red',
  };
  return chip(key, label);
}