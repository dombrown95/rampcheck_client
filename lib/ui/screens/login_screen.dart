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
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive width for the login form depending on device.
    final widthFactor = screenWidth < 600 ? 1.0 : 0.5;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Container(
                width: 32,
                height: 32,
                color: Colors.white,
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/rampcheck_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.flight_takeoff, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RampCheck — Sign in',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'worker', child: Text('Worker')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'manager'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                          child: const Text(
                            'Create account',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
