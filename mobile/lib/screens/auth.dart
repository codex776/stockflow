import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Auth, signup and organization setup — port of src/screens/auth.js.
// ====================================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signupMode = false;
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  String? err;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  void _run(Function submit) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await submit();
    } catch (e) {
      if (mounted) setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            _logo(),
            const SizedBox(height: 32),
            const Text('Track every item,',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const Text('everywhere you work.',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 8),
            const Text(
                'Count, move, and reorder stock across every shelf, van, and store.',
                style: TextStyle(fontSize: 13.5, color: C.muted, height: 1.45)),
            const SizedBox(height: 28),
            SegControl<bool>(
              options: [
                (value: false, label: 'Sign in'),
                (value: true, label: 'Create account'),
              ],
              current: signupMode,
              onChanged: (v) => setState(() {
                signupMode = v;
                err = null;
              }),
            ),
            const SizedBox(height: 18),
            if (signupMode) ...[
              Labeled(
                label: 'Your name',
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(hintText: 'e.g. Sara Abdi'),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Labeled(
              label: 'Email',
              child: TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'you@company.com'),
              ),
            ),
            const SizedBox(height: 14),
            Labeled(
              label: 'Password',
              child: TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(
                    hintText: '8+ characters with a number'),
              ),
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.redBg,
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: C.redSoft),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_rounded, color: C.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(err!,
                            style: const TextStyle(
                                fontSize: 13, color: C.red))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => _run(() {
                        if (signupMode) {
                          Store.instance.signUp(
                              name: name.text,
                              email: email.text,
                              pass: pass.text);
                        } else {
                          Store.instance.login(email.text, pass.text);
                        }
                      }),
              child: Text(signupMode
                  ? 'Create account'
                  : busy
                      ? 'Signing in…'
                      : 'Sign in'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() => Store.instance.loginDemo()),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Try the demo — Sunrise Coffee Traders'),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text('Accounts are stored only on this device.',
                  style: const TextStyle(fontSize: 12, color: C.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: C.navy,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Text('StockFlow',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// -------------------------------------------------------------------
class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key});

  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> {
  final name = TextEditingController();
  String industry = 'Retail & Food';
  final locName = TextEditingController();
  final invite = TextEditingController();
  bool joinMode = false;
  String? err;
  bool busy = false;

  static const industries = [
    'Retail & Food',
    'Wholesale',
    'Manufacturing',
    'Healthcare',
    'Construction',
    'E-commerce',
    'Performing Arts',
    'Other',
  ];

  @override
  void dispose() {
    name.dispose();
    locName.dispose();
    invite.dispose();
    super.dispose();
  }

  void _run(Function submit) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await submit();
      Store.instance.boot();
    } catch (e) {
      if (mounted) setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(joinMode ? 'Join with invite code' : 'Set up your business'),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: C.muted),
          onPressed: () => Store.instance.logout(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SegControl<bool>(
            options: [
              (value: false, label: 'Create new'),
              (value: true, label: 'I was invited'),
            ],
            current: joinMode,
            onChanged: (v) => setState(() => joinMode = v),
          ),
          const SizedBox(height: 18),
          if (joinMode) ...[
            Labeled(
              label: 'Invite code',
              hint: 'e.g. SF-7K2D9',
              child: TextField(
                controller: invite,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Invite code',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
            ),
          ] else ...[
            Labeled(
              label: 'Business name',
              child: TextField(
                controller: name,
                decoration: const InputDecoration(hintText: 'e.g. Sunrise Coffee'),
              ),
            ),
            const SizedBox(height: 14),
            Labeled(
              label: 'Industry',
              child: DropdownButtonFormField<String>(
                initialValue: industry,
                decoration: const InputDecoration(),
                items: [
                  for (final i in industries)
                    DropdownMenuItem(value: i, child: Text(i)),
                ],
                onChanged: (v) => setState(() => industry = v ?? industry),
              ),
            ),
            const SizedBox(height: 14),
            Labeled(
              label: 'Main location',
              hint: 'Where is most stock kept?',
              child: TextField(
                controller: locName,
                decoration: const InputDecoration(
                    hintText: 'e.g. Main Warehouse'),
              ),
            ),
          ],
          if (err != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.redBg,
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: C.redSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded, color: C.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(err!,
                          style: const TextStyle(fontSize: 13, color: C.red))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () => _run(() {
                      if (joinMode) {
                        if (invite.text.trim().isEmpty) {
                          throw Exception('Enter your invite code');
                        }
                        Store.instance.joinOrg(invite.text);
                      } else {
                        if (name.text.trim().isEmpty) {
                          throw Exception('Business name is required');
                        }
                        Store.instance.createOrg(
                          name: name.text,
                          industry: industry,
                          locName: locName.text,
                          locType: 'warehouse',
                        );
                      }
                    }),
            child: Text(joinMode ? 'Join organization' : 'Create workspace'),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: C.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Everything lives on this device. Your team can join with the invite code.',
                    style: TextStyle(fontSize: 12, color: C.muted, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}