import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../data/remote/api_client.dart';
import '../../models/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});
  final LocalStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String _role = 'manager';
  bool _busy = false;

  String _baseUrlForPlatform(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';
  }

  Future<void> _login() async {
    final username = _user.text.trim();
    final password = _pass.text;

    if (username.isEmpty || password.isEmpty) return;

    setState(() => _busy = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final api = WarehouseApiClient(baseUrl: _baseUrlForPlatform(context));
      await api.login(username: username, password: password);

      await widget.store.saveSession(
        Session(username: username, password: password, role: _role),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/jobs');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    final username = _user.text.trim();
    final password = _pass.text;

    if (username.isEmpty || password.isEmpty) return;

    setState(() => _busy = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final api = WarehouseApiClient(baseUrl: _baseUrlForPlatform(context));
      await api.createUser(username: username, password: password, role: _role);

      await widget.store.saveSession(
        Session(username: username, password: password, role: _role),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/jobs');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RampCheck — Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'manager', child: Text('manager')),
                DropdownMenuItem(value: 'worker', child: Text('worker')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'manager'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _login,
                    child: Text(_busy ? 'Please wait…' : 'Log in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _createAccount,
                    child: const Text('Create account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
