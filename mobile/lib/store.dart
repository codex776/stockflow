import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

export 'models.dart' hide AppState;

// ====================================================================
// StockFlow store — offline-first state, persistence, sync outbox,
// immutable movement log, low-stock alerting. Port of src/store.js.
// ====================================================================

class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  static const lsKey = 'stockflow.v1';
  AppState state = AppState();

  static late SharedPreferences _prefs;

  static Future<void> ensureReady() async {
    _prefs = await SharedPreferences.getInstance();
    Store.instance.init();
  }

  void init() => state = load() ?? AppState();

  AppState? load() {
    try {
      final raw = _prefs.getString(lsKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['v'] == 1) return AppState.fromJson(j);
      }
    } catch (_) {}
    return null;
  }

  void save() {
    try {
      _prefs.setString(lsKey, jsonEncode(state.toJson()));
    } catch (_) {}
    notifyListeners();
  }

  void wipeAll() {
    try {
      _prefs.remove(lsKey);
    } catch (_) {}
    state = AppState();
    notifyListeners();
  }

  /// Clears the first-launch flag (called once after the splash screen).
  void boot() {
    if (state.firstLaunch) {
      state.firstLaunch = false;
      save();
    }
  }

  AppState get S => state;

  // ======================== generic getters ========================
  Session? session() => state.session.userId == null ? null : state.session;

  User? currentUser() {
    final s = session();
    if (s == null) return null;
    final idx = state.users.indexWhere((u) => u.id == s.userId);
    return idx < 0 ? null : state.users[idx];
  }

  Org? currentOrg() {
    final s = session();
    if (s?.orgId == null) return null;
    final idx = state.orgs.indexWhere((o) => o.id == s?.orgId);
    return idx < 0 ? null : state.orgs[idx];
  }

  bool isPro() {
    final o = currentOrg();
    return o != null && (o.plan == 'pro' || o.plan == 'trial');
  }

  String role() => currentUser()?.role ?? 'staff';

  bool can(String perm) {
    final r = role();
    switch (perm) {
      case 'viewCosts':
      case 'manageTeam':
      case 'approveCounts':
      case 'manageSuppliers':
        return r == 'owner' || r == 'manager';
      case 'manageOrg':
        return r == 'owner';
      default:
        return true;
    }
  }

  String get _orgId => state.session.orgId ?? '';

  List<Item> orgItems() => state.items.where((i) => i.orgId == _orgId).toList();
  List<Item> activeItems() => orgItems().where((i) => i.status == 'active').toList();

  Item? itemById(String id) {
    final idx = state.items.indexWhere((i) => i.id == id);
    return idx < 0 ? null : state.items[idx];
  }

  Item? findByBarcode(String code) {
    for (final i in orgItems()) {
      if (i.barcode == code && i.status == 'active') return i;
    }
    return null;
  }

  List<Location> locations() =>
      state.locations.where((l) => l.orgId == _orgId && !l.archived).toList();

  Location? locationById(String id) {
    final idx = state.locations.indexWhere((l) => l.id == id);
    return idx < 0 ? null : state.locations[idx];
  }

  List<String> categories() => state.cats[_orgId] ?? [];

  List<Supplier> suppliers() =>
      state.suppliers.where((s) => s.orgId == _orgId && !s.archived).toList();

  Supplier? supplierById(String? id) {
    if (id == null) return null;
    final idx = state.suppliers.indexWhere((s) => s.id == id);
    return idx < 0 ? null : state.suppliers[idx];
  }

  List<TeamMember> teamList() => state.team.where((t) => t.orgId == _orgId).toList();

  List<Po> posList() {
    final l = state.pos.where((p) => p.orgId == _orgId).toList();
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  Po? poById(String id) {
    final idx = state.pos.indexWhere((p) => p.id == id);
    return idx < 0 ? null : state.pos[idx];
  }

  List<CycleCount> countsList() {
    final l = state.counts.where((c) => c.orgId == _orgId).toList();
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  CycleCount? countById(String id) {
    final idx = state.counts.indexWhere((c) => c.id == id);
    return idx < 0 ? null : state.counts[idx];
  }

  List<AppNotif> notifsList() {
    final l = state.notifs.where((n) => n.orgId == _orgId).toList();
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l;
  }

  int unreadCount() => notifsList().where((n) => !n.read).length;
  int outboxPending() => state.outbox.length;

  List<Movement> movements([int n = 50]) {
    final l = state.movements.where((m) => m.orgId == _orgId).toList();
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l.take(n).toList();
  }

  List<Movement> itemMovements(String itemId, [int n = 24]) {
    final l = state.movements.where((m) => m.itemId == itemId).toList();
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l.take(n).toList();
  }

  // ====================== inventory helpers ======================
  Level? level(String itemId, String locId) {
    final idx = state.levels
        .indexWhere((l) => l.itemId == itemId && l.locationId == locId);
    return idx < 0 ? null : state.levels[idx];
  }

  int levelQty(String itemId, String locId) => level(itemId, locId)?.onHand ?? 0;

  int totalOn(String itemId) =>
      state.levels.where((l) => l.itemId == itemId).fold(0, (a, l) => a + l.onHand);

  int totalReserved(String itemId) =>
      state.levels.where((l) => l.itemId == itemId).fold(0, (a, l) => a + (l.reserved));

  /// Returns {key, label} — key is 'in' | 'low' | 'out' | 'arch'.
  ({String key, String label}) statusOf(Item item, [String? locId]) {
    if (item.status == 'archived') return (key: 'arch', label: 'Archived');
    final q = locId != null ? levelQty(item.id, locId) : totalOn(item.id);
    if (q <= 0) return (key: 'out', label: 'Out of stock');
    if (item.reorderPoint > 0 && q <= item.reorderPoint) {
      return (key: 'low', label: 'Low stock');
    }
    return (key: 'in', label: 'In stock');
  }

  List<({Item item, ({String key, String label}) st})> lowItems() =>
      activeItems()
          .where((i) => !i.alertsMuted)
          .map((i) => (item: i, st: statusOf(i)))
          .where((x) => x.st.key == 'low' || x.st.key == 'out')
          .toList();

  double orgStockValue() => activeItems().fold(0, (a, i) => a + totalOn(i.id) * (i.cost));

  List<({Location loc, double value, int units})> valueByLocation() =>
      locations()
          .map((loc) => (
                loc: loc,
                value: activeItems().fold(0.0, (a, i) => a + levelQty(i.id, loc.id) * (i.cost)),
                units: activeItems().fold(0, (a, i) => a + levelQty(i.id, loc.id)),
              ))
          .toList();

  double valueAtLocation(String locId) =>
      activeItems().fold(0.0, (a, i) => a + levelQty(i.id, locId) * (i.cost));

  int openPOCount() => posList()
      .where((p) => ['draft', 'sent', 'partial'].contains(p.status))
      .length;

  // ====================== outbox / sync ======================
  bool queueOp(String label) {
    final offline = !state.ui.online;
    if (offline) state.outbox.add(OutboxOp()..id = uid('op')..label = label..ts = now());
    return offline;
  }

  void setOnline(bool online) {
    state.ui.online = online;
    save();
    if (online) processOutbox();
  }

  void setManualOffline(bool v) {
    state.ui.manualOffline = v;
    setOnline(!v);
  }

  Future<void> processOutbox() async {
    final st = state;
    if (st.ui.syncing || !st.ui.online || st.outbox.isEmpty) return;
    st.ui.syncing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 650));
    while (st.outbox.isNotEmpty) {
      st.outbox.removeAt(0);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    for (final m in st.movements) {
      m.pending = false;
    }
    st.ui.syncing = false;
    st.ui.lastSyncAt = now();
    save();
  }

  Future<void> syncNow() => processOutbox();

  // ==================== core movement writer ====================
  Movement applyMovement(
      String itemId, String locId, String type, int delta, {
      String? reason, String? notes, String? ref}) {
    final st = state;
    final item = itemById(itemId);
    final org = currentOrg();
    if (item == null) throw Exception('Item not found');
    var lv = level(itemId, locId);
    if (lv == null) {
      lv = Level()
        ..itemId = itemId
        ..locationId = locId
        ..onHand = 0
        ..reserved = 0
        ..alerted = false
        ..updatedAt = now();
      st.levels.add(lv);
    }
    final before = lv.onHand;
    final after = before + delta;
    if (after < 0 && !(org?.settings.allowNegative ?? false)) {
      final locName = locationById(locId)?.name ?? 'location';
      throw Exception(
          'Not enough stock at $locName — only $before ${item.unit} on hand. Enable “Allow negative stock” in Settings to override.');
    }
    lv.onHand = after;
    lv.updatedAt = now();
    final m = Movement()
      ..id = uid('mv')
      ..orgId = item.orgId
      ..itemId = itemId
      ..locationId = locId
      ..type = type
      ..delta = delta
      ..qtyAfter = after
      ..reason = reason
      ..notes = notes
      ..ref = ref
      ..user = currentUser()?.name ?? 'System'
      ..ts = now()
      ..pending = !st.ui.online;
    st.movements.add(m);
    if (type == 'count') {
      item.lastCountedAt = m.ts;
    }
    item.updatedAt = m.ts;
    queueOp('${mvLabel(type)} ${delta > 0 ? '+' : ''}$delta × ${item.name}');
    _evaluateLowStock(item, lv, before, after);
    return m;
  }

  String mvLabel(String t) {
    const map = {
      'receive': 'Received',
      'issue': 'Issued',
      'adjust': 'Adjusted',
      'transfer_out': 'Transfer out',
      'transfer_in': 'Transfer in',
      'count': 'Cycle count',
      'return': 'Returned',
      'waste': 'Waste',
    };
    return map[t] ?? t;
  }

  void _evaluateLowStock(Item item, Level lv, int before, int after) {
    final rp = item.reorderPoint;
    if (rp <= 0) return;
    final crossedDown = before > rp && after <= rp;
    final crossedZero = before > 0 && after <= 0;
    if ((crossedDown || crossedZero) && !item.alertsMuted && !lv.alerted) {
      lv.alerted = true;
      final loc = locationById(lv.locationId);
      pushNotif(
        type: 'lowStock',
        title: after <= 0 ? 'Out of stock' : 'Low stock alert',
        body:
            '${item.name} is ${after <= 0 ? 'out of stock' : 'down to $after ${item.unit}'} at ${loc?.name}. Reorder point: $rp.',
        link: '/items/${item.id}',
      );
    }
    if (after > rp) lv.alerted = false;
  }

  void pushNotif({required String type, required String title, required String body, required String link}) {
    final muted = switch (type) {
      'lowStock' => state.prefs.lowStock,
      'poUpdates' => state.prefs.poUpdates,
      'invites' => state.prefs.invites,
      'counts' => state.prefs.counts,
      'conflicts' => state.prefs.conflicts,
      _ => true,
    };
    if (!muted) return;
    state.notifs.add(AppNotif()
      ..id = uid('nt')
      ..orgId = state.session.orgId ?? ''
      ..type = type
      ..title = title
      ..body = body
      ..link = link
      ..ts = now()
      ..read = false);
  }

  // ====================== stock actions ======================
  Movement quickReceive(String itemId, String locId, int qty, [String? notes]) {
    if (qty <= 0) throw Exception('Quantity must be greater than zero');
    final m = applyMovement(itemId, locId, 'receive', qty,
        reason: 'Goods received', notes: notes);
    save();
    return m;
  }

  Movement quickIssue(String itemId, String locId, int qty, String? reason, [String? notes]) {
    if (qty <= 0) throw Exception('Quantity must be greater than zero');
    final m = applyMovement(itemId, locId, 'issue', -qty,
        reason: reason ?? 'Sale / usage', notes: notes);
    save();
    return m;
  }

  Movement quickAdjust(String itemId, String locId, int delta, String? reason, [String? notes]) {
    if (delta == 0) throw Exception('Enter a quantity to adjust');
    final type = delta < 0 && (reason == 'Damage' || reason == 'Expired') ? 'waste' : 'adjust';
    final m = applyMovement(itemId, locId, type, delta,
        reason: reason ?? 'Correction', notes: notes);
    save();
    return m;
  }

  Movement quickCount(String itemId, String locId, int physical, [String? notes]) {
    final current = levelQty(itemId, locId);
    final delta = physical - current;
    final m = applyMovement(itemId, locId, 'count', delta,
        reason: 'Ad-hoc count',
        notes:
            'Counted $physical (system $current)${notes != null && notes.isNotEmpty ? ' — $notes' : ''}');
    save();
    return m;
  }

  void transferStock(String itemId, String fromId, String toId, int qty, [String? notes]) {
    if (qty <= 0) throw Exception('Quantity must be greater than zero');
    if (fromId == toId) throw Exception('Source and destination must be different');
    final ref = uid('tr');
    applyMovement(itemId, fromId, 'transfer_out', -qty,
        reason: 'Stock transfer', notes: notes, ref: ref);
    applyMovement(itemId, toId, 'transfer_in', qty,
        reason: 'Stock transfer', notes: notes, ref: ref);
    save();
  }

  // ========================== items ==========================
  bool skuExists(String sku, [String? exceptId]) => orgItems().any(
      (i) => i.sku.toLowerCase() == sku.toLowerCase() && i.id != exceptId);

  bool barcodeExists(String? code, [String? exceptId]) =>
      code != null && code.isNotEmpty &&
      orgItems().any((i) => i.barcode == code && i.id != exceptId);

  Item addItem(Item data, Map<String, int> initialStock) {
    final st = state;
    if (data.name.trim().isEmpty) throw Exception('Item name is required');
    if (skuExists(data.sku)) {
      throw Exception('SKU “${data.sku}” already exists in this organization');
    }
    if (barcodeExists(data.barcode)) {
      throw Exception('Barcode ${data.barcode} is already assigned to another item');
    }
    final item = Item()
      ..id = uid('it')
      ..orgId = state.session.orgId ?? ''
      ..status = 'active'
      ..createdAt = now()
      ..updatedAt = now()
      ..lastCountedAt = null
      ..alertsMuted = false
      ..image = data.image;
    // copy fields from data
    item
      ..name = data.name
      ..sku = data.sku
      ..barcode = data.barcode
      ..description = data.description
      ..category = data.category
      ..unit = data.unit
      ..cost = data.cost
      ..price = data.price
      ..reorderPoint = data.reorderPoint
      ..reorderQty = data.reorderQty
      ..supplierId = data.supplierId;
    st.items.add(item);
    queueOp('Created item ${item.name}');
    if (initialStock.isNotEmpty) {
      initialStock.forEach((locId, q) {
        if (q > 0) applyMovement(item.id, locId, 'adjust', q, reason: 'Initial stock');
      });
    }
    save();
    return item;
  }

  Item updateItem(String id, Item data) {
    final item = itemById(id);
    if (item == null) throw Exception('Item not found');
    if (data.sku.isNotEmpty && skuExists(data.sku, id)) {
      throw Exception('SKU “${data.sku}” already exists in this organization');
    }
    if (barcodeExists(data.barcode, id)) {
      throw Exception('Barcode ${data.barcode} is already assigned to another item');
    }
    item
      ..name = data.name
      ..sku = data.sku
      ..barcode = data.barcode
      ..description = data.description
      ..category = data.category
      ..unit = data.unit
      ..cost = data.cost
      ..price = data.price
      ..reorderPoint = data.reorderPoint
      ..reorderQty = data.reorderQty
      ..supplierId = data.supplierId
      ..image = data.image
      ..updatedAt = now();
    queueOp('Updated item ${item.name}');
    save();
    return item;
  }

  void archiveItem(String id, [bool archived = true]) {
    final item = itemById(id);
    if (item == null) return;
    item.status = archived ? 'archived' : 'active';
    item.updatedAt = now();
    queueOp('${archived ? 'Archived' : 'Restored'} item ${item.name}');
    save();
  }

  void muteItem(String id, bool muted) {
    final item = itemById(id);
    if (item != null) {
      item.alertsMuted = muted;
      save();
    }
  }

  void addCategory(String name) {
    final list = state.cats.putIfAbsent(_orgId, () => []);
    if (!list.contains(name)) list.add(name);
    save();
  }

  // ======================== locations ========================
  Location addLocation(String name, String type, String address) {
    final org = currentOrg();
    if (org != null && org.plan == 'free' && locations().isNotEmpty) {
      throw _LimitError('LIMIT_LOCATIONS');
    }
    final loc = Location()
      ..id = uid('lc')
      ..orgId = org?.id ?? ''
      ..archived = false
      ..createdAt = now()
      ..name = name
      ..type = type
      ..address = address;
    state.locations.add(loc);
    queueOp('Created location ${loc.name}');
    save();
    return loc;
  }

  void archiveLocation(String id) {
    final hasStock =
        state.levels.any((l) => l.locationId == id && l.onHand > 0);
    if (hasStock) {
      throw Exception(
          'This location still has stock on hand. Transfer it to another location first.');
    }
    final loc = locationById(id);
    if (loc == null) return;
    loc.archived = true;
    queueOp('Archived location ${loc.name}');
    save();
  }

  void updateLocation(Location loc, {required String name, required String type, required String address}) {
    loc
      ..name = name.trim()
      ..type = type
      ..address = address.trim();
    save();
  }

  // ======================== suppliers ========================
  Supplier addSupplier(Supplier data) {
    if (state.suppliers.any((s) =>
        s.orgId == _orgId &&
        !s.archived &&
        s.name.toLowerCase() == data.name.toLowerCase())) {
      throw Exception('A supplier named “${data.name}” already exists');
    }
    final sup = Supplier()
      ..id = uid('sp')
      ..orgId = _orgId
      ..archived = false
      ..createdAt = now()
      ..name = data.name
      ..contact = data.contact
      ..email = data.email
      ..phone = data.phone
      ..address = data.address
      ..leadTimeDays = data.leadTimeDays
      ..terms = data.terms
      ..notes = data.notes;
    state.suppliers.add(sup);
    queueOp('Added supplier ${sup.name}');
    save();
    return sup;
  }

  void updateSupplier(String id, Supplier data) {
    final s = supplierById(id);
    if (s == null) return;
    s
      ..name = data.name
      ..contact = data.contact
      ..email = data.email
      ..phone = data.phone
      ..address = data.address
      ..leadTimeDays = data.leadTimeDays
      ..terms = data.terms
      ..notes = data.notes;
    queueOp('Updated supplier ${s.name}');
    save();
  }

  void archiveSupplier(String id) {
    if (state.pos.any((p) =>
        p.supplierId == id && ['draft', 'sent', 'partial'].contains(p.status))) {
      throw Exception('This supplier has open purchase orders. Close them first.');
    }
    final s = supplierById(id);
    if (s == null) return;
    s.archived = true;
    queueOp('Archived supplier ${s.name}');
    save();
  }

  // ==================== purchase orders ====================
  Po createPO({
    required String supplierId,
    required List<({String itemId, int qty, double? unitCost})> lines,
    int? expectedDate,
    String? notes,
  }) {
    if (lines.isEmpty) throw Exception('Add at least one line item');
    final org = currentOrg();
    org?.poSeq = (org.poSeq == 0 ? 1044 : org.poSeq) + 1;
    final number = 'PO-${org?.poSeq}';
    final po = Po()
      ..id = uid('po')
      ..orgId = _orgId
      ..number = number
      ..supplierId = supplierId
      ..expectedDate = expectedDate
      ..notes = notes ?? ''
      ..status = 'draft'
      ..createdAt = now()
      ..history = [
        PoEvent()..ts = now()..event = 'Created as draft'..user = currentUser()?.name ?? ''
      ];
    for (final l in lines) {
      final item = itemById(l.itemId);
      po.lines.add(PoLine()
        ..itemId = l.itemId
        ..qtyOrdered = l.qty
        ..qtyReceived = 0
        ..unitCost = l.unitCost ?? item?.cost ?? 0);
    }
    state.pos.add(po);
    queueOp('Created $number');
    save();
    return po;
  }

  String poStatus(Po po) {
    final total = po.lines.fold<int>(0, (a, l) => a + l.qtyOrdered);
    final got = po.lines.fold<int>(0, (a, l) => a + l.qtyReceived);
    if (po.status == 'cancelled') return 'cancelled';
    if (po.status == 'draft') return 'draft';
    if (got <= 0) return 'sent';
    if (got < total) return 'partial';
    return 'received';
  }

  void updatePOContent(String id,
      {String? supplierId, int? expectedDate, String? notes,
        List<({String itemId, int qty, double? unitCost})>? lines}) {
    final po = poById(id);
    if (po == null) return;
    if (po.status != 'draft') throw Exception('Only drafts can be edited');
    if (supplierId != null) po.supplierId = supplierId;
    if (expectedDate != null) po.expectedDate = expectedDate;
    if (notes != null) po.notes = notes;
    if (lines != null) {
      if (lines.isEmpty) throw Exception('Add at least one line item');
      po.lines = [
        for (final l in lines)
          PoLine()
            ..itemId = l.itemId
            ..qtyOrdered = l.qty
            ..qtyReceived = 0
            ..unitCost = l.unitCost ?? itemById(l.itemId)?.cost ?? 0,
      ];
    }
    po.history.add(PoEvent()
      ..ts = now()
      ..event = 'Draft edited'
      ..user = currentUser()?.name ?? '');
    queueOp('${po.number} edited');
    save();
  }

  double poTotal(Po po) => po.lines.fold<double>(0, (a, l) => a + l.qtyOrdered * l.unitCost);

  void sendPO(String id) {
    final po = poById(id);
    if (po == null) return;
    if (po.status != 'draft') throw Exception('Only draft POs can be marked as sent');
    po.status = 'sent';
    po.history.add(PoEvent()
      ..ts = now()
      ..event = 'Marked as sent to supplier'
      ..user = currentUser()?.name ?? '');
    queueOp('${po.number} sent');
    save();
  }

  void cancelPO(String id) {
    final po = poById(id);
    if (po == null) return;
    if (['received', 'cancelled'].contains(po.status)) {
      throw Exception('This PO can no longer be cancelled');
    }
    po.status = 'cancelled';
    po.history.add(PoEvent()..ts = now()..event = 'Cancelled'..user = currentUser()?.name ?? '');
    pushNotif(
      type: 'poUpdates',
      title: '${po.number} cancelled',
      body:
          'Purchase order to ${supplierById(po.supplierId)?.name} was cancelled.',
      link: '/orders/${po.id}',
    );
    queueOp('${po.number} cancelled');
    save();
  }

  void receivePO(String id, List<({String itemId, int qty})> receipts, String locId, String? note) {
    final po = poById(id);
    if (po == null) return;
    final st = poStatus(po);
    if (!['sent', 'partial'].contains(st)) throw Exception('This PO is not awaiting receipt');
    var any = false;
    for (final r in receipts) {
      final lineIdx = po.lines.indexWhere((l) => l.itemId == r.itemId);
      if (lineIdx < 0 || r.qty <= 0) continue;
      any = true;
      po.lines[lineIdx].qtyReceived += r.qty;
      applyMovement(r.itemId, locId, 'receive', r.qty,
          reason: 'PO ${po.number} receipt', notes: note, ref: po.id);
    }
    if (!any) throw Exception('Enter a quantity for at least one line');
    final newStatus = poStatus(po);
    if (newStatus != 'draft') po.status = newStatus;
    final done = newStatus == 'received';
    po.history.add(PoEvent()
      ..ts = now()
      ..event = done ? 'Fully received' : 'Partially received'
      ..user = currentUser()?.name ?? '');
    pushNotif(
      type: 'poUpdates',
      title: '${po.number} ${done ? 'received' : 'partially received'}',
      body: done
          ? 'All items received at ${locationById(locId)?.name}.'
          : 'Some items still outstanding from ${supplierById(po.supplierId)?.name}.',
      link: '/orders/${po.id}',
    );
    save();
  }

  ({Po po, bool merged}) createPOFromLowStock(Item item) {
    final qty = [
      item.reorderQty,
      item.reorderPoint * 2 - totalOn(item.id),
      1
    ].reduce((a, b) => a > b ? a : b);
    final existing = posList()
        .where((p) => p.status == 'draft' && p.supplierId == item.supplierId)
        .cast<Po?>()
        .firstWhere((_) => true, orElse: () => null);
    if (existing != null) {
      if (!existing.lines.any((l) => l.itemId == item.id)) {
        existing.lines.add(PoLine()
          ..itemId = item.id
          ..qtyOrdered = qty
          ..qtyReceived = 0
          ..unitCost = item.cost);
      }
      save();
      return (po: existing, merged: true);
    }
    final po = createPO(
        supplierId: item.supplierId ?? (suppliers().isNotEmpty ? suppliers().first.id : ''),
        lines: [(itemId: item.id, qty: qty, unitCost: null)],
        notes: 'Auto-created from low stock alert');
    return (po: po, merged: false);
  }

  // ====================== cycle counts ======================
  CycleCount startCount(String locId, String scope) {
    var pool = activeItems();
    if (scope == 'suggested') {
      final monthAgo = now() - 30 * dayMs;
      pool = pool.where((i) => i.lastCountedAt == null || i.lastCountedAt! < monthAgo).take(8).toList();
      if (pool.isEmpty) pool = activeItems().take(8).toList();
    } else {
      pool = pool.take(40).toList();
    }
    final c = CycleCount()
      ..id = uid('ct')
      ..orgId = _orgId
      ..locationId = locId
      ..scope = scope
      ..status = 'open'
      ..createdAt = now()
      ..createdBy = currentUser()?.name;
    for (final i in pool) {
      c.items.add(CountLine()
        ..itemId = i.id
        ..systemQty = levelQty(i.id, locId)
        ..countedQty = null);
    }
    state.counts.add(c);
    queueOp('Started cycle count');
    save();
    return c;
  }

  void setCountQty(String countId, String itemId, int? qty) {
    final c = countById(countId);
    if (c == null) return;
    final idx = c.items.indexWhere((x) => x.itemId == itemId);
    if (idx >= 0) {
      c.items[idx].countedQty = qty;
      save();
    }
  }

  void finishCountToReview(String countId) {
    final c = countById(countId);
    if (c == null) return;
    if (!c.items.any((x) => x.countedQty != null)) {
      throw Exception('Count at least one item before reviewing');
    }
    c.status = 'review';
    save();
  }

  int approveCount(String countId, List<String> approvedItemIds) {
    final c = countById(countId);
    if (c == null) return 0;
    var applied = 0;
    for (final line in c.items) {
      if (line.countedQty == null) continue;
      if (!approvedItemIds.contains(line.itemId)) continue;
      final delta = line.countedQty! - (line.systemQty ?? 0);
      if (delta != 0) {
        final variance = delta > 0 ? '+$delta' : '$delta';
        applyMovement(line.itemId, c.locationId, 'count', delta,
            reason: 'Cycle count variance',
            notes:
                'Count ${c.id.substring(c.id.length - 4)}: physical ${line.countedQty} vs system ${line.systemQty} ($variance)',
            ref: c.id);
        applied++;
      } else {
        final it = itemById(line.itemId);
        if (it != null) it.lastCountedAt = now();
      }
    }
    c.status = 'done';
    c.completedAt = now();
    pushNotif(
      type: 'counts',
      title: 'Cycle count completed',
      body:
          '${locationById(c.locationId)?.name}: $applied adjustment${applied == 1 ? '' : 's'} applied.',
      link: '/counts/${c.id}',
    );
    save();
    return applied;
  }

  void cancelCount(String countId) {
    final c = countById(countId);
    if (c != null) {
      c.status = 'cancelled';
      save();
    }
  }

  // ========================== team ==========================
  TeamMember inviteMember(String email, String mrole) {
    final org = currentOrg();
    if (org != null && org.plan == 'free' && teamList().length >= 2) {
      throw _LimitError('LIMIT_TEAM');
    }
    if (teamList().any((t) => t.email.toLowerCase() == email.toLowerCase())) {
      throw Exception('This person is already on your team');
    }
    final colors = ['a', 'b', 'c', 'd', 'e', 'f'];
    final m = TeamMember()
      ..id = uid('tm')
      ..orgId = org?.id ?? ''
      ..name = email.split('@')[0].replaceAll(RegExp(r'[._]'), ' ')
      ..email = email
      ..role = mrole
      ..status = 'invited'
      ..invitedAt = now()
      ..color = 'av-${colors[now() % colors.length]}';
    state.team.add(m);
    pushNotif(
      type: 'invites',
      title: 'Invitation sent',
      body:
          '$email was invited as $mrole. Share invite code ${org?.inviteCode} with them.',
      link: '/team',
    );
    queueOp('Invited $email');
    save();
    return m;
  }

  void setMemberRole(String memberId, String newRole) {
    final idx = state.team.indexWhere((t) => t.id == memberId);
    if (idx < 0) return;
    final m = state.team[idx];
    final ownerCount = teamList().where((t) => t.role == 'owner').length;
    if (m.role == 'owner' && ownerCount <= 1) {
      throw Exception('The last owner cannot be demoted. Transfer ownership first.');
    }
    m.role = newRole;
    save();
  }

  void removeMember(String memberId) {
    final idx = state.team.indexWhere((t) => t.id == memberId);
    if (idx < 0) return;
    final m = state.team[idx];
    final ownerCount = teamList().where((t) => t.role == 'owner').length;
    if (m.role == 'owner' && ownerCount <= 1) {
      throw Exception('The last owner cannot leave the organization');
    }
    state.team.removeAt(idx);
    queueOp('Removed ${m.email}');
    save();
  }

  // ===================== notifications =====================
  void notifRead(String id) {
    final idx = state.notifs.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      state.notifs[idx].read = true;
      save();
    }
  }

  void notifReadAll() {
    for (final n in notifsList()) {
      n.read = true;
    }
    save();
  }

  void setPref(String k, dynamic v) {
    switch (k) {
      case 'lowStock': state.prefs.lowStock = v as bool; break;
      case 'poUpdates': state.prefs.poUpdates = v as bool; break;
      case 'invites': state.prefs.invites = v as bool; break;
      case 'counts': state.prefs.counts = v as bool; break;
      case 'conflicts': state.prefs.conflicts = v as bool; break;
      case 'quietOn': state.prefs.quietOn = v as bool; break;
      case 'quietFrom': state.prefs.quietFrom = v as String; break;
      case 'quietTo': state.prefs.quietTo = v as String; break;
      case 'haptics': state.prefs.haptics = v as bool; break;
      case 'sounds': state.prefs.sounds = v as bool; break;
      case 'biometric': state.prefs.biometric = v as bool; break;
      case 'primed': state.prefs.primed = v as bool; break;
    }
    save();
  }

  // ========================== plan ==========================
  void upgradePlan() {
    final org = currentOrg();
    if (org != null) org.plan = 'pro';
    save();
  }

  void downgradeToFree() {
    final org = currentOrg();
    if (org != null) org.plan = 'free';
    save();
  }

  bool checkSKULimit() {
    final org = currentOrg();
    return org != null && org.plan == 'free' && activeItems().length >= 100;
  }

  // =========================== auth ===========================
  String _normEmail(String? e) => (e ?? '').trim().toLowerCase();

  String? passwordIssues(String? pw) {
    if (pw == null || pw.length < 8) return 'Password must be at least 8 characters';
    if (!pw.contains(RegExp(r'\d'))) return 'Add at least one number to your password';
    return null;
  }

  User signUp({required String name, required String email, required String pass}) {
    final em = _normEmail(email);
    if (name.trim().isEmpty) throw Exception('Your name is required');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(em)) {
      throw Exception('Enter a valid email address');
    }
    final pwIssue = passwordIssues(pass);
    if (pwIssue != null) throw Exception(pwIssue);
    if (state.users.any((u) => u.email == em)) {
      throw Exception('An account with this email already exists. Try signing in.');
    }
    final user = User()
      ..id = uid('us')
      ..name = name.trim()
      ..email = em
      ..pass = pass
      ..createdAt = now()
      ..color = 'av-a';
    state.users.add(user);
    state.session = Session(user.id, null);
    save();
    return user;
  }

  User login(String email, String pass) {
    final em = _normEmail(email);
    final idx = state.users.indexWhere((u) => u.email == em);
    final u = idx < 0 ? null : state.users[idx];
    if (u == null || u.pass != pass) throw Exception('Incorrect email or password');
    u.role ??= 'owner';
    state.session = Session(u.id, u.orgIds.isNotEmpty ? u.orgIds.first : null);
    save();
    return u;
  }

  void loginDemo() {
    var user = state.users.where((u) => u.id == 'us_demo').firstOrNull;
    if (user == null) {
      seedDemo(state);
      user = state.users.where((u) => u.id == 'us_demo').first;
    }
    state.session = Session(user.id, user.orgIds.first);
    save();
  }

  void logout() {
    state.session = Session.empty();
    save();
  }

  void deleteAccount() {
    wipeAll();
  }

  // =========================== org ===========================
  Org createOrg({
    required String name,
    required String industry,
    required String locName,
    required String locType,
  }) {
    final user = currentUser()!;
    final st = state;
    final org = Org()
      ..id = uid('og')
      ..name = name.trim()
      ..industry = industry
      ..plan = 'trial'
      ..trialDays = 14
      ..poSeq = 1000
      ..inviteCode = 'SF-${uid('').substring(1, 6).toUpperCase()}'
      ..createdAt = now();
    org.settings = OrgSettings()..allowNegative = false..currency = 'USD';
    st.orgs.add(org);
    user.orgIds.add(org.id);
    user.role = 'owner';
    state.session.orgId = org.id;
    st.cats[org.id] = ['General'];
    st.team.add(TeamMember()
      ..id = uid('tm')
      ..orgId = org.id
      ..name = user.name
      ..email = user.email
      ..role = 'owner'
      ..status = 'active'
      ..color = 'av-a');
    st.locations.add(Location()
      ..id = uid('lc')
      ..orgId = org.id
      ..name = locName.trim().isEmpty ? 'Main Location' : locName.trim()
      ..type = locType.isEmpty ? 'warehouse' : locType
      ..address = ''
      ..archived = false
      ..createdAt = now());
    queueOp('Created organization ${org.name}');
    save();
    return org;
  }

  Org joinOrg(String code) {
    final trimmed = (code).trim().toUpperCase();
    final org = state.orgs.where((o) => o.inviteCode.toUpperCase() == trimmed).firstOrNull;
    if (org == null) {
      throw Exception('Invalid or expired invite code. Ask the owner for a new one.');
    }
    final user = currentUser()!;
    if (user.orgIds.contains(org.id)) {
      throw Exception('You are already a member of this organization');
    }
    user.orgIds.add(org.id);
    state.team.add(TeamMember()
      ..id = uid('tm')
      ..orgId = org.id
      ..name = user.name
      ..email = user.email
      ..role = 'staff'
      ..status = 'active'
      ..color = 'av-c');
    state.session.orgId = org.id;
    pushNotif(
      type: 'invites',
      title: 'Welcome to ${org.name}',
      body: 'You joined as Staff. The owner can change your role anytime.',
      link: '/home',
    );
    save();
    return org;
  }

  void switchOrg(String orgId) {
    final user = currentUser();
    if (user == null || !user.orgIds.contains(orgId)) {
      throw Exception('You are not a member of that organization');
    }
    state.session.orgId = orgId;
    save();
  }

  void setRoleDemo(String r) {
    final u = currentUser();
    if (u != null) {
      u.role = r;
      save();
    }
  }

  void updateProfile({String? name, String? pass}) {
    final u = currentUser();
    if (u == null) return;
    if (name != null && name.isNotEmpty) u.name = name;
    if (pass != null && pass.isNotEmpty) {
      final i = passwordIssues(pass);
      if (i != null) throw Exception(i);
      u.pass = pass;
    }
    save();
  }

  // ======================= DEMO SEED =======================
  void seedDemo(AppState st) {
    final t0 = now();
    final org = Org()
      ..id = 'og_demo'
      ..name = 'Sunrise Coffee Traders'
      ..industry = 'Retail & Food'
      ..plan = 'trial'
      ..trialDays = 14
      ..poSeq = 1044
      ..inviteCode = 'SF-7K2D9'
      ..createdAt = t0 - 84 * dayMs;
    org.settings = OrgSettings()..allowNegative = false..currency = 'USD';
    st.orgs.add(org);

    User mkUser(String id, String name, String email, String urole, String color) =>
        User()
          ..id = id
          ..name = name
          ..email = email
          ..pass = 'demo1234'
          ..role = urole
          ..color = color
          ..createdAt = t0 - 80 * dayMs
          ..orgIds = [org.id];
    st.users.add(mkUser('us_demo', 'Alex Mushi', 'alex@sunrisecoffee.co', 'owner', 'av-a'));
    st.users.add(mkUser('us_neema', 'Neema Kessy', 'neema@sunrisecoffee.co', 'manager', 'av-d'));
    st.users.add(mkUser('us_baraka', 'Baraka Mollel', 'baraka@sunrisecoffee.co', 'staff', 'av-b'));
    st.team.addAll([
      TeamMember()..id = 'tm1'..orgId = org.id..name = 'Alex Mushi'..email = 'alex@sunrisecoffee.co'..role = 'owner'..status = 'active'..color = 'av-a',
      TeamMember()..id = 'tm2'..orgId = org.id..name = 'Neema Kessy'..email = 'neema@sunrisecoffee.co'..role = 'manager'..status = 'active'..color = 'av-d',
      TeamMember()..id = 'tm3'..orgId = org.id..name = 'Baraka Mollel'..email = 'baraka@sunrisecoffee.co'..role = 'staff'..status = 'active'..color = 'av-b',
      TeamMember()..id = 'tm4'..orgId = org.id..name = 'Joseph Mbwana'..email = 'joseph.mbwana@gmail.com'..role = 'staff'..status = 'invited'..invitedAt = t0 - 2 * dayMs..color = 'av-f',
    ]);

    Location mkLoc(String id, String name, String type, String address, int createdDaysAgo) =>
        Location()..id = id..orgId = org.id..name = name..type = type..address = address..archived = false..createdAt = t0 - createdDaysAgo * dayMs;
    st.locations.addAll([
      mkLoc('lc_wh', 'Main Warehouse', 'warehouse', 'Plot 42, Nyerere Rd', 84),
      mkLoc('lc_st', 'Downtown Store', 'store', '18 Uhuru Street', 84),
      mkLoc('lc_van', 'Delivery Van 02', 'vehicle', '', 60),
    ]);

    Supplier mkSup(String id, String name, String contact, String email, String phone, String address, int lead, String terms, String notes, int createdAgo) =>
        Supplier()..id = id..orgId = org.id..name = name..contact = contact..email = email..phone = phone..address = address..leadTimeDays = lead..terms = terms..notes = notes..archived = false..createdAt = t0 - createdAgo * dayMs;
    st.suppliers.addAll([
      mkSup('sp_kili', 'Kilimanjaro Coffee Co.', 'Amani Joseph', 'orders@kilimanjarocoffee.co', '+255 754 210 334', 'Moshi, Kilimanjaro', 7, 'Net 30', 'Preferred for all green & roasted beans.', 80),
      mkSup('sp_pack', 'PackRight Ltd', 'Grace Mushi', 'sales@packright.com', '+255 767 555 010', 'Industrial Area, Dar es Salaam', 4, 'Net 14', '', 78),
      mkSup('sp_nord', 'Nordic Dairy Supply', 'Elin Larsson', 'hello@nordicdairy.se', '+46 70 224 8890', 'Malmö, Sweden', 10, 'Net 30', 'Oat milk ships in 96-carton pallets.', 75),
      mkSup('sp_tea', 'Mombasa Tea Traders', 'David Otieno', 'david@mombasatea.com', '+254 733 902 118', 'Mombasa, Kenya', 12, 'Net 45', '', 70),
    ]);
    st.cats[org.id] = ['Beverages', 'Food', 'Merchandise', 'Packaging', 'Equipment'];

    // [id, name, sku, barcode, cat, unit, cost, price, rp, rq, supplier, wh, st, van]
    final items = [
      ['it_arb', 'Arabica Coffee Beans 1kg', 'CF-ARB-1K', '850001234501', 'Beverages', 'bag', 11.50, 18.00, 24, 60, 'sp_kili', 42, 8, 0],
      ['it_cbrew', 'Cold Brew Bottle 330ml', 'CF-CB-330', '850001234502', 'Beverages', 'bottle', 1.10, 3.50, 48, 144, 'sp_kili', 156, 24, 36],
      ['it_oat', 'Oat Milk 1L', 'BW-OAT-1L', '850001234503', 'Beverages', 'carton', 1.60, 3.20, 24, 48, 'sp_nord', 12, 6, 0],
      ['it_cups', 'Paper Cups 12oz (500ct)', 'PK-CUP-12', '850001234504', 'Packaging', 'case', 22.00, 38.00, 6, 12, 'sp_pack', 9, 2, 1],
      ['it_mug', 'Ceramic Mug 350ml', 'MR-MUG-350', '850001234505', 'Merchandise', 'piece', 3.80, 12.00, 10, 24, 'sp_pack', 30, 12, 0],
      ['it_matcha', 'Matcha Powder 500g', 'CF-MAT-500', '850001234506', 'Beverages', 'pouch', 8.40, 16.00, 8, 20, 'sp_tea', 0, 4, 0],
      ['it_crois', 'Chocolate Croissant', 'FD-CRO-CH', '850001234507', 'Food', 'piece', 0.90, 3.00, 12, 40, 'sp_pack', 0, 18, 0],
      ['it_tote', 'Sunrise Tote Bag', 'MR-TOTE', '850001234508', 'Merchandise', 'piece', 2.20, 9.00, 8, 20, 'sp_pack', 14, 6, 0],
      ['it_esp', 'Espresso Blend 250g', 'CF-ESP-250', '850001234509', 'Beverages', 'bag', 5.20, 11.00, 20, 48, 'sp_kili', 55, 14, 8],
      ['it_lids', 'Cup Lids 12oz (1000ct)', 'PK-LID-12', '850001234510', 'Packaging', 'case', 14.00, 24.00, 8, 12, 'sp_pack', 7, 3, 0],
      ['it_van', 'Vanilla Syrup 750ml', 'BW-VAN-750', '850001234511', 'Beverages', 'bottle', 4.10, 9.50, 6, 12, 'sp_nord', 11, 2, 0],
      ['it_filter', 'V60 Filter Papers (100ct)', 'PK-FLT-V60', '850001234512', 'Packaging', 'pack', 3.10, 7.00, 10, 20, 'sp_pack', 26, 9, 0],
      ['it_clean', 'Cleaning Tablets (120ct)', 'EQ-CLN-120', '850001234513', 'Equipment', 'jar', 9.80, 15.00, 4, 8, 'sp_nord', 5, 1, 0],
      ['it_tea', 'Swahili Tea Sampler Box', 'CF-TEA-BX', '850001234514', 'Beverages', 'box', 6.50, 14.00, 6, 24, 'sp_tea', 18, 7, 0],
      ['it_hol', 'Holiday Blend 2024', 'CF-HOL-24', '850001234515', 'Beverages', 'bag', 12.00, 22.00, 0, 0, 'sp_kili', 0, 0, 0],
      ['it_straw', 'Paper Straws (250ct)', 'PK-STR-250', '850001234516', 'Packaging', 'pack', 2.40, 5.00, 4, 8, 'sp_pack', 0, 2, 0],
    ];
    for (final row in items) {
      final id = row[0] as String;
      final name = row[1] as String;
      final sku = row[2] as String;
      final barcode = row[3] as String;
      final cat = row[4] as String;
      final unit = row[5] as String;
      final cost = (row[6] as num).toDouble();
      final price = (row[7] as num).toDouble();
      final rp = row[8] as int;
      final rq = row[9] as int;
      final supplierId = row[10] as String;
      final wh = row[11] as int;
      final stq = row[12] as int;
      final van = row[13] as int;
      final archived = id == 'it_hol' || id == 'it_straw';
      st.items.add(Item()
        ..id = id
        ..orgId = org.id
        ..name = name
        ..sku = sku
        ..barcode = barcode
        ..description = ''
        ..category = cat
        ..unit = unit
        ..cost = cost
        ..price = price
        ..reorderPoint = rp
        ..reorderQty = rq
        ..supplierId = supplierId
        ..image = null
        ..status = archived ? 'archived' : 'active'
        ..createdAt = t0 - 70 * dayMs
        ..updatedAt = t0 - 2 * dayMs
        ..lastCountedAt = null
        ..alertsMuted = id == 'it_straw');
      void put(String locId, int q) {
        st.levels.add(Level()
          ..itemId = id
          ..locationId = locId
          ..onHand = q
          ..reserved = 0
          ..alerted = rp > 0 && q > 0 && q <= rp
          ..updatedAt = t0 - 2 * dayMs);
      }
      put('lc_wh', wh);
      put('lc_st', stq);
      put('lc_van', van);
    }

    // purchase orders
    st.pos.addAll([
      Po()
        ..id = 'po_1041'
        ..orgId = org.id
        ..number = 'PO-1041'
        ..supplierId = 'sp_nord'
        ..status = 'received'
        ..lines = [PoLine()..itemId = 'it_oat'..qtyOrdered = 96..qtyReceived = 96..unitCost = 1.60]
        ..expectedDate = t0 - 16 * dayMs
        ..notes = 'Regular monthly pallet.'
        ..createdAt = t0 - 26 * dayMs
        ..history = [
          PoEvent()..ts = t0 - 26 * dayMs..event = 'Created as draft'..user = 'Alex Mushi',
          PoEvent()..ts = t0 - 25 * dayMs..event = 'Marked as sent to supplier'..user = 'Alex Mushi',
          PoEvent()..ts = t0 - 16 * dayMs..event = 'Fully received'..user = 'Neema Kessy',
        ],
      Po()
        ..id = 'po_1042'
        ..orgId = org.id
        ..number = 'PO-1042'
        ..supplierId = 'sp_kili'
        ..status = 'partial'
        ..lines = [
          PoLine()..itemId = 'it_arb'..qtyOrdered = 60..qtyReceived = 20..unitCost = 11.50,
          PoLine()..itemId = 'it_esp'..qtyOrdered = 48..qtyReceived = 0..unitCost = 5.20,
        ]
        ..expectedDate = t0 + 5 * dayMs
        ..notes = 'Ask driver to call on arrival.'
        ..createdAt = t0 - 8 * dayMs
        ..history = [
          PoEvent()..ts = t0 - 8 * dayMs..event = 'Created as draft'..user = 'Alex Mushi',
          PoEvent()..ts = t0 - 8 * dayMs..event = 'Marked as sent to supplier'..user = 'Alex Mushi',
          PoEvent()..ts = t0 - 2 * dayMs..event = 'Partially received'..user = 'Baraka Mollel',
        ],
      Po()
        ..id = 'po_1043'
        ..orgId = org.id
        ..number = 'PO-1043'
        ..supplierId = 'sp_pack'
        ..status = 'draft'
        ..lines = [
          PoLine()..itemId = 'it_cups'..qtyOrdered = 12..qtyReceived = 0..unitCost = 22.00,
          PoLine()..itemId = 'it_lids'..qtyOrdered = 8..qtyReceived = 0..unitCost = 14.00,
        ]
        ..expectedDate = t0 + 9 * dayMs
        ..notes = ''
        ..createdAt = t0 - 1 * dayMs
        ..history = [
          PoEvent()..ts = t0 - 1 * dayMs..event = 'Created as draft'..user = 'Neema Kessy',
        ],
      Po()
        ..id = 'po_1044'
        ..orgId = org.id
        ..number = 'PO-1044'
        ..supplierId = 'sp_tea'
        ..status = 'sent'
        ..lines = [PoLine()..itemId = 'it_tea'..qtyOrdered = 24..qtyReceived = 0..unitCost = 6.50]
        ..expectedDate = t0 + 12 * dayMs
        ..notes = 'Include new seasonal sampler flyer.'
        ..createdAt = t0 - 3 * dayMs
        ..history = [
          PoEvent()..ts = t0 - 3 * dayMs..event = 'Created as draft'..user = 'Alex Mushi',
          PoEvent()..ts = t0 - 3 * dayMs..event = 'Marked as sent to supplier'..user = 'Alex Mushi',
        ],
    ]);

    // seeded movement history, last 30 days (deterministic rng)
    int rngS = 42;
    double rnd() {
      rngS = (rngS * 1103515245 + 12345) % 2147483648;
      return rngS / 2147483648;
    }
    const mvloc = ['lc_wh', 'lc_st', 'lc_st', 'lc_van'];
    const usersN = ['Neema Kessy', 'Baraka Mollel', 'Alex Mushi'];
    final activeIds = items
        .where((i) => i[0] != 'it_hol' && i[0] != 'it_straw')
        .map((i) => i[0] as String)
        .toList();
    for (var d = 30; d >= 1; d--) {
      final n = 1 + (rnd() * 3).floor();
      for (var k = 0; k < n; k++) {
        final id = activeIds[(rnd() * activeIds.length).floor()];
        final loc = mvloc[(rnd() * mvloc.length).floor()];
        final ts =
            t0 - d * dayMs + (rnd() * 9 * 3600000).floor() + 8 * 3600000;
        final r = rnd();
        String type, reason;
        int delta;
        if (r < 0.62) {
          type = 'issue';
          delta = -(1 + (rnd() * 5).floor());
          reason = 'Sale / usage';
        } else if (r < 0.82) {
          type = 'receive';
          delta = [12, 24, 48, 96][(rnd() * 4).floor()];
          reason = 'Goods received';
        } else if (r < 0.93) {
          type = 'adjust';
          delta = rnd() < 0.5 ? -1 : 1;
          reason = ['Correction', 'Damage', 'Found'][(rnd() * 3).floor()];
        } else {
          type = 'return';
          delta = 1 + (rnd() * 2).floor();
          reason = 'Customer return';
        }
        final lvIdx =
            st.levels.indexWhere((l) => l.itemId == id && l.locationId == loc);
        final lv = lvIdx < 0 ? null : st.levels[lvIdx];
        st.movements.add(Movement()
          ..id = uid('mv')
          ..orgId = org.id
          ..itemId = id
          ..locationId = loc
          ..type = type
          ..delta = delta
          ..qtyAfter = (lv != null ? lv.onHand : 0) + delta
          ..reason = reason
          ..notes = null
          ..ref = null
          ..user = usersN[(rnd() * 3).floor()]
          ..ts = ts
          ..pending = false);
      }
    }

    // one completed count
    st.counts.add(CycleCount()
      ..id = 'ct_done'
      ..orgId = org.id
      ..locationId = 'lc_st'
      ..scope = 'suggested'
      ..status = 'done'
      ..createdAt = t0 - 6 * dayMs
      ..completedAt = t0 - 6 * dayMs + 3600000
      ..createdBy = 'Baraka Mollel'
      ..items = [
        CountLine()..itemId = 'it_arb'..systemQty = 8..countedQty = 8,
        CountLine()..itemId = 'it_cups'..systemQty = 3..countedQty = 2,
        CountLine()..itemId = 'it_mug'..systemQty = 12..countedQty = 12,
      ]);

    // notifications
    st.notifs.addAll([
      AppNotif()..id = uid('nt')..orgId = org.id..type = 'lowStock'..title = 'Low stock alert'..body = 'Oat Milk 1L is down to 12 cartons total. Reorder point: 24.'..link = '/items/it_oat'..ts = t0 - 3 * 3600000..read = false,
      AppNotif()..id = uid('nt')..orgId = org.id..type = 'poUpdates'..title = 'PO-1042 partially received'..body = '20 of 60 Arabica Coffee Beans 1kg received. Balance expected in 5 days.'..link = '/orders/po_1042'..ts = t0 - 2 * dayMs..read = false,
      AppNotif()..id = uid('nt')..orgId = org.id..type = 'counts'..title = 'Cycle count completed'..body = 'Downtown Store: 1 adjustment applied by Baraka Mollel.'..link = '/counts/ct_done'..ts = t0 - 6 * dayMs..read = true,
      AppNotif()..id = uid('nt')..orgId = org.id..type = 'invites'..title = 'Invitation sent'..body = 'joseph.mbwana@gmail.com was invited as staff.'..link = '/team'..ts = t0 - 2 * dayMs..read = true,
    ]);
    st.items.where((i) => i.id == 'it_crois').forEach((i) => i.lastCountedAt = t0 - 40 * dayMs);
    st.items.where((i) => i.id == 'it_oat').forEach((i) => i.lastCountedAt = t0 - 12 * dayMs);
  }
}

class _LimitError implements Exception {
  final String code;
  _LimitError(this.code);
  @override
  String toString() => code;
}

// small helper so screens can distinguish limit errors
bool isLimitError(Object e) => e is _LimitError;