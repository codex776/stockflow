import 'dart:math';

// ====================================================================
// StockFlow data models — mirror of the web app's localStorage schema.
// ====================================================================

String uid([String p = 'id']) {
  final rnd = Random();
  final r = List.generate(8, (_) => rnd.nextInt(36)).map(_b36).join();
  final tx = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final s = tx.length <= 3 ? tx : tx.substring(tx.length - 3);
  return '${p}_$r$s';
}

String _b36(int v) => v < 10 ? '$v' : String.fromCharCode(97 + v - 10);

int now() => DateTime.now().millisecondsSinceEpoch;

const int dayMs = 86400000;

/// Auto-SKU generated from an item name, e.g. "Oat Milk 1L" -> "OM-1L-842".
String genSku(String name) {
  final w = name
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (w.isEmpty) return 'ITEM-${100 + Random().nextInt(900)}';
  final head = w.take(2).map((s) => s[0]).join();
  final digs = w.last.replaceAll(RegExp(r'[^0-9]'), '');
  final suffix = 100 + Random().nextInt(900);
  return digs.isNotEmpty ? '$head-$digs-$suffix' : '$head-$suffix';
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : 0;
int _toInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

class Session {
  String? userId;
  String? orgId;
  Session([this.userId, this.orgId]);
  Session.empty() : userId = null, orgId = null;
  bool get authed => userId != null && userId!.isNotEmpty;
  bool get hasOrg => orgId != null && orgId!.isNotEmpty;
  Map<String, dynamic> toJson() => {'userId': userId, 'orgId': orgId};
  static Session fromJson(dynamic j) => Session(j?['userId'], j?['orgId']);
}

class Prefs {
  bool lowStock = true, poUpdates = true, invites = true, counts = true, conflicts = true;
  bool quietOn = false, haptics = true, sounds = true, biometric = false, primed = false;
  String quietFrom = '22:00', quietTo = '07:00';
  Map<String, dynamic> toJson() => {
        'lowStock': lowStock, 'poUpdates': poUpdates, 'invites': invites,
        'counts': counts, 'conflicts': conflicts, 'quietOn': quietOn,
        'quietFrom': quietFrom, 'quietTo': quietTo, 'haptics': haptics,
        'sounds': sounds, 'biometric': biometric, 'primed': primed,
      };
  static Prefs fromJson(dynamic j) {
    final p = Prefs();
    if (j is! Map) return p;
    p.lowStock = j['lowStock'] ?? true;
    p.poUpdates = j['poUpdates'] ?? true;
    p.invites = j['invites'] ?? true;
    p.counts = j['counts'] ?? true;
    p.conflicts = j['conflicts'] ?? true;
    p.quietOn = j['quietOn'] ?? false;
    p.quietFrom = j['quietFrom'] ?? '22:00';
    p.quietTo = j['quietTo'] ?? '07:00';
    p.haptics = j['haptics'] ?? true;
    p.sounds = j['sounds'] ?? true;
    p.biometric = j['biometric'] ?? false;
    p.primed = j['primed'] ?? false;
    return p;
  }
}

class UIState {
  bool online = true, manualOffline = false, syncing = false;
  int? lastSyncAt;
  Map<String, dynamic> toJson() =>
      {'online': online, 'manualOffline': manualOffline, 'syncing': syncing, 'lastSyncAt': lastSyncAt};
  static UIState fromJson(dynamic j) {
    final u = UIState();
    if (j is! Map) return u;
    u.online = j['online'] ?? true;
    u.manualOffline = j['manualOffline'] ?? false;
    u.syncing = j['syncing'] ?? false;
    u.lastSyncAt = j['lastSyncAt'];
    return u;
  }
}

class OrgSettings {
  bool allowNegative = false;
  String currency = 'USD';
  Map<String, dynamic> toJson() => {'allowNegative': allowNegative, 'currency': currency};
  static OrgSettings fromJson(dynamic j) {
    final s = OrgSettings();
    if (j is Map) {
      s.allowNegative = j['allowNegative'] ?? false;
      s.currency = j['currency'] ?? 'USD';
    }
    return s;
  }
}

class User {
  String id = '', name = '', email = '';
  String? pass;
  String color = 'av-a';
  String? role;
  int createdAt = 0;
  List<String> orgIds = [];
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email, 'pass': pass, 'color': color,
        'role': role, 'createdAt': createdAt, 'orgIds': orgIds,
      };
  static User fromJson(dynamic j) {
    final u = User();
    if (j is! Map) return u;
    u.id = j['id'] ?? '';
    u.name = j['name'] ?? '';
    u.email = j['email'] ?? '';
    u.pass = j['pass'];
    u.color = j['color'] ?? 'av-a';
    u.role = j['role'];
    u.createdAt = j['createdAt'] ?? now();
    u.orgIds = List<String>.from(j['orgIds'] ?? []);
    return u;
  }
}

class Org {
  String id = '', name = '', industry = '', plan = 'free', inviteCode = '';
  int trialDays = 14, poSeq = 1000, createdAt = 0;
  OrgSettings settings = OrgSettings();
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'industry': industry, 'plan': plan, 'trialDays': trialDays,
        'poSeq': poSeq, 'inviteCode': inviteCode, 'createdAt': createdAt, 'settings': settings.toJson(),
      };
  static Org fromJson(dynamic j) {
    final o = Org();
    if (j is! Map) return o;
    o.id = j['id'] ?? '';
    o.name = j['name'] ?? '';
    o.industry = j['industry'] ?? '';
    o.plan = j['plan'] ?? 'free';
    o.trialDays = j['trialDays'] ?? 14;
    o.poSeq = j['poSeq'] ?? 1000;
    o.inviteCode = j['inviteCode'] ?? '';
    o.createdAt = j['createdAt'] ?? now();
    o.settings = OrgSettings.fromJson(j['settings']);
    return o;
  }
}

class Location {
  String id = '', orgId = '', name = '', type = 'warehouse', address = '';
  bool archived = false;
  int createdAt = 0;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'name': name, 'type': type, 'address': address,
        'archived': archived, 'createdAt': createdAt,
      };
  static Location fromJson(dynamic j) {
    final l = Location();
    if (j is! Map) return l;
    l.id = j['id'] ?? '';
    l.orgId = j['orgId'] ?? '';
    l.name = j['name'] ?? '';
    l.type = j['type'] ?? 'warehouse';
    l.address = j['address'] ?? '';
    l.archived = j['archived'] ?? false;
    l.createdAt = j['createdAt'] ?? now();
    return l;
  }
}

class Item {
  String id = '', orgId = '', name = '', sku = '', barcode = '', description = '';
  String category = 'General', unit = 'pcs';
  double cost = 0, price = 0;
  int reorderPoint = 0, reorderQty = 0;
  String? supplierId;
  String? image;
  String status = 'active';
  bool alertsMuted = false;
  int createdAt = 0, updatedAt = 0;
  int? lastCountedAt;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'name': name, 'sku': sku, 'barcode': barcode,
        'description': description, 'category': category, 'unit': unit, 'cost': cost,
        'price': price, 'reorderPoint': reorderPoint, 'reorderQty': reorderQty,
        'supplierId': supplierId, 'image': image, 'status': status,
        'alertsMuted': alertsMuted, 'createdAt': createdAt, 'updatedAt': updatedAt,
        'lastCountedAt': lastCountedAt,
      };
  static Item fromJson(dynamic j) {
    final i = Item();
    if (j is! Map) return i;
    i.id = j['id'] ?? '';
    i.orgId = j['orgId'] ?? '';
    i.name = j['name'] ?? '';
    i.sku = j['sku'] ?? '';
    i.barcode = j['barcode'] ?? '';
    i.description = j['description'] ?? '';
    i.category = j['category'] ?? 'General';
    i.unit = j['unit'] ?? 'pcs';
    i.cost = _toDouble(j['cost']);
    i.price = _toDouble(j['price']);
    i.reorderPoint = _toInt(j['reorderPoint']);
    i.reorderQty = _toInt(j['reorderQty']);
    i.supplierId = j['supplierId'];
    i.image = j['image'];
    i.status = j['status'] ?? 'active';
    i.alertsMuted = j['alertsMuted'] ?? false;
    i.createdAt = j['createdAt'] ?? now();
    i.updatedAt = j['updatedAt'] ?? now();
    i.lastCountedAt = j['lastCountedAt'];
    return i;
  }
}

class Level {
  String itemId = '', locationId = '';
  int onHand = 0, reserved = 0;
  bool alerted = false;
  int updatedAt = 0;
  Map<String, dynamic> toJson() => {
        'itemId': itemId, 'locationId': locationId, 'onHand': onHand,
        'reserved': reserved, 'alerted': alerted, 'updatedAt': updatedAt,
      };
  static Level fromJson(dynamic j) {
    final l = Level();
    if (j is! Map) return l;
    l.itemId = j['itemId'] ?? '';
    l.locationId = j['locationId'] ?? '';
    l.onHand = j['onHand'] ?? 0;
    l.reserved = j['reserved'] ?? 0;
    l.alerted = j['alerted'] ?? false;
    l.updatedAt = j['updatedAt'] ?? now();
    return l;
  }
}

class Movement {
  String id = '', orgId = '', itemId = '', locationId = '', type = 'adjust';
  int delta = 0, qtyAfter = 0, ts = 0;
  String? reason, notes, ref, user;
  bool pending = false;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'itemId': itemId, 'locationId': locationId,
        'type': type, 'delta': delta, 'qtyAfter': qtyAfter, 'reason': reason,
        'notes': notes, 'ref': ref, 'user': user, 'ts': ts, 'pending': pending,
      };
  static Movement fromJson(dynamic j) {
    final m = Movement();
    if (j is! Map) return m;
    m.id = j['id'] ?? '';
    m.orgId = j['orgId'] ?? '';
    m.itemId = j['itemId'] ?? '';
    m.locationId = j['locationId'] ?? '';
    m.type = j['type'] ?? 'adjust';
    m.delta = j['delta'] ?? 0;
    m.qtyAfter = j['qtyAfter'] ?? 0;
    m.reason = j['reason'];
    m.notes = j['notes'];
    m.ref = j['ref'];
    m.user = j['user'];
    m.ts = j['ts'] ?? now();
    m.pending = j['pending'] ?? false;
    return m;
  }
}

class Supplier {
  String id = '', orgId = '', name = '', contact = '', email = '', phone = '', address = '';
  String terms = '', notes = '';
  int? leadTimeDays;
  bool archived = false;
  int createdAt = 0;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'name': name, 'contact': contact, 'email': email,
        'phone': phone, 'address': address, 'terms': terms, 'notes': notes,
        'leadTimeDays': leadTimeDays, 'archived': archived, 'createdAt': createdAt,
      };
  static Supplier fromJson(dynamic j) {
    final s = Supplier();
    if (j is! Map) return s;
    s.id = j['id'] ?? '';
    s.orgId = j['orgId'] ?? '';
    s.name = j['name'] ?? '';
    s.contact = j['contact'] ?? '';
    s.email = j['email'] ?? '';
    s.phone = j['phone'] ?? '';
    s.address = j['address'] ?? '';
    s.terms = j['terms'] ?? '';
    s.notes = j['notes'] ?? '';
    s.leadTimeDays = j['leadTimeDays'];
    s.archived = j['archived'] ?? false;
    s.createdAt = j['createdAt'] ?? now();
    return s;
  }
}

class PoLine {
  String itemId = '';
  int qtyOrdered = 0, qtyReceived = 0;
  double unitCost = 0;
  Map<String, dynamic> toJson() =>
      {'itemId': itemId, 'qtyOrdered': qtyOrdered, 'qtyReceived': qtyReceived, 'unitCost': unitCost};
  static PoLine fromJson(dynamic j) {
    final l = PoLine();
    if (j is! Map) return l;
    l.itemId = j['itemId'] ?? '';
    l.qtyOrdered = j['qtyOrdered'] ?? 0;
    l.qtyReceived = j['qtyReceived'] ?? 0;
    l.unitCost = _toDouble(j['unitCost']);
    return l;
  }
}

class PoEvent {
  int ts = 0;
  String event = '', user = '';
  Map<String, dynamic> toJson() => {'ts': ts, 'event': event, 'user': user};
  static PoEvent fromJson(dynamic j) {
    final e = PoEvent();
    if (j is! Map) return e;
    e.ts = j['ts'] ?? now();
    e.event = j['event'] ?? '';
    e.user = j['user'] ?? '';
    return e;
  }
}

class Po {
  String id = '', orgId = '', number = '', supplierId = '', notes = '';
  String status = 'draft';
  int? expectedDate;
  int createdAt = 0;
  List<PoLine> lines = [];
  List<PoEvent> history = [];
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'number': number, 'supplierId': supplierId,
        'lines': lines.map((l) => l.toJson()).toList(), 'expectedDate': expectedDate,
        'notes': notes, 'status': status, 'createdAt': createdAt,
        'history': history.map((h) => h.toJson()).toList(),
      };
  static Po fromJson(dynamic j) {
    final p = Po();
    if (j is! Map) return p;
    p.id = j['id'] ?? '';
    p.orgId = j['orgId'] ?? '';
    p.number = j['number'] ?? '';
    p.supplierId = j['supplierId'] ?? '';
    p.notes = j['notes'] ?? '';
    p.status = j['status'] ?? 'draft';
    p.expectedDate = j['expectedDate'];
    p.createdAt = j['createdAt'] ?? now();
    p.lines = (j['lines'] as List? ?? []).map((x) => PoLine.fromJson(x)).toList();
    p.history = (j['history'] as List? ?? []).map((x) => PoEvent.fromJson(x)).toList();
    return p;
  }
}

class CountLine {
  String itemId = '';
  int? systemQty, countedQty;
  Map<String, dynamic> toJson() =>
      {'itemId': itemId, 'systemQty': systemQty, 'countedQty': countedQty};
  static CountLine fromJson(dynamic j) {
    final l = CountLine();
    if (j is! Map) return l;
    l.itemId = j['itemId'] ?? '';
    l.systemQty = j['systemQty'];
    l.countedQty = j['countedQty'];
    return l;
  }
}

class CycleCount {
  String id = '', orgId = '', locationId = '', scope = 'suggested', status = 'open';
  String? createdBy;
  int createdAt = 0;
  int? completedAt;
  List<CountLine> items = [];
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'locationId': locationId, 'scope': scope,
        'status': status, 'createdAt': createdAt, 'completedAt': completedAt,
        'createdBy': createdBy, 'items': items.map((x) => x.toJson()).toList(),
      };
  static CycleCount fromJson(dynamic j) {
    final c = CycleCount();
    if (j is! Map) return c;
    c.id = j['id'] ?? '';
    c.orgId = j['orgId'] ?? '';
    c.locationId = j['locationId'] ?? '';
    c.scope = j['scope'] ?? 'suggested';
    c.status = j['status'] ?? 'open';
    c.createdAt = j['createdAt'] ?? now();
    c.completedAt = j['completedAt'];
    c.createdBy = j['createdBy'];
    c.items = (j['items'] as List? ?? []).map((x) => CountLine.fromJson(x)).toList();
    return c;
  }
}

class TeamMember {
  String id = '', orgId = '', name = '', email = '', role = 'staff', status = 'active', color = 'av-c';
  int invitedAt = 0;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'name': name, 'email': email, 'role': role,
        'status': status, 'color': color, 'invitedAt': invitedAt,
      };
  static TeamMember fromJson(dynamic j) {
    final m = TeamMember();
    if (j is! Map) return m;
    m.id = j['id'] ?? '';
    m.orgId = j['orgId'] ?? '';
    m.name = j['name'] ?? '';
    m.email = j['email'] ?? '';
    m.role = j['role'] ?? 'staff';
    m.status = j['status'] ?? 'active';
    m.color = j['color'] ?? 'av-c';
    m.invitedAt = j['invitedAt'] ?? now();
    return m;
  }
}

class AppNotif {
  String id = '', orgId = '', type = 'info', title = '', body = '', link = '';
  int ts = 0;
  bool read = false;
  Map<String, dynamic> toJson() => {
        'id': id, 'orgId': orgId, 'type': type, 'title': title, 'body': body,
        'link': link, 'ts': ts, 'read': read,
      };
  static AppNotif fromJson(dynamic j) {
    final n = AppNotif();
    if (j is! Map) return n;
    n.id = j['id'] ?? '';
    n.orgId = j['orgId'] ?? '';
    n.type = j['type'] ?? 'info';
    n.title = j['title'] ?? '';
    n.body = j['body'] ?? '';
    n.link = j['link'] ?? '';
    n.ts = j['ts'] ?? now();
    n.read = j['read'] ?? false;
    return n;
  }
}

class OutboxOp {
  String id = '', label = '';
  int ts = 0;
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'ts': ts};
  static OutboxOp fromJson(dynamic j) {
    final o = OutboxOp();
    if (j is! Map) return o;
    o.id = j['id'] ?? '';
    o.label = j['label'] ?? '';
    o.ts = j['ts'] ?? now();
    return o;
  }
}

// ============================ STATE ============================

class AppState {
  int v = 1;
  bool firstLaunch = true;
  Session session = Session.empty();
  List<User> users = [];
  List<Org> orgs = [];
  List<Location> locations = [];
  List<Item> items = [];
  List<Level> levels = [];
  List<Movement> movements = [];
  List<Supplier> suppliers = [];
  List<Po> pos = [];
  List<CycleCount> counts = [];
  List<TeamMember> team = [];
  List<AppNotif> notifs = [];
  List<OutboxOp> outbox = [];
  Prefs prefs = Prefs();
  UIState ui = UIState();
  Map<String, List<String>> cats = {};

  Map<String, dynamic> toJson() => {
        'v': v, 'firstLaunch': firstLaunch, 'session': session.toJson(),
        'users': users.map((x) => x.toJson()).toList(),
        'orgs': orgs.map((x) => x.toJson()).toList(),
        'locations': locations.map((x) => x.toJson()).toList(),
        'items': items.map((x) => x.toJson()).toList(),
        'levels': levels.map((x) => x.toJson()).toList(),
        'movements': movements.map((x) => x.toJson()).toList(),
        'suppliers': suppliers.map((x) => x.toJson()).toList(),
        'pos': pos.map((x) => x.toJson()).toList(),
        'counts': counts.map((x) => x.toJson()).toList(),
        'team': team.map((x) => x.toJson()).toList(),
        'notifs': notifs.map((x) => x.toJson()).toList(),
        'outbox': outbox.map((x) => x.toJson()).toList(),
        'prefs': prefs.toJson(), 'ui': ui.toJson(),
        'cats': cats.map((k, v) => MapEntry(k, v)),
      };

  static AppState fromJson(Map<String, dynamic> j) {
    final s = AppState();
    s.firstLaunch = j['firstLaunch'] ?? true;
    s.session = Session.fromJson(j['session']);
    s.users = (j['users'] as List? ?? []).map((x) => User.fromJson(x)).toList();
    s.orgs = (j['orgs'] as List? ?? []).map((x) => Org.fromJson(x)).toList();
    s.locations = (j['locations'] as List? ?? []).map((x) => Location.fromJson(x)).toList();
    s.items = (j['items'] as List? ?? []).map((x) => Item.fromJson(x)).toList();
    s.levels = (j['levels'] as List? ?? []).map((x) => Level.fromJson(x)).toList();
    s.movements = (j['movements'] as List? ?? []).map((x) => Movement.fromJson(x)).toList();
    s.suppliers = (j['suppliers'] as List? ?? []).map((x) => Supplier.fromJson(x)).toList();
    s.pos = (j['pos'] as List? ?? []).map((x) => Po.fromJson(x)).toList();
    s.counts = (j['counts'] as List? ?? []).map((x) => CycleCount.fromJson(x)).toList();
    s.team = (j['team'] as List? ?? []).map((x) => TeamMember.fromJson(x)).toList();
    s.notifs = (j['notifs'] as List? ?? []).map((x) => AppNotif.fromJson(x)).toList();
    s.outbox = (j['outbox'] as List? ?? []).map((x) => OutboxOp.fromJson(x)).toList();
    s.prefs = Prefs.fromJson(j['prefs']);
    s.ui = UIState.fromJson(j['ui']);
    s.cats = ((j['cats'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k.toString(), List<String>.from(v as List? ?? [])));
    return s;
  }
}