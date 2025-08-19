import 'package:flutter/material.dart';

class AddUserScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onUserAdded;
  final String currentUserRole;

  const AddUserScreen({
    super.key,
    required this.onUserAdded,
    required this.currentUserRole,
  });

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canChooseRole = widget.currentUserRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('زیادکردنی بەکارهێنەری نوێ'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Icon(Icons.person_add_alt_1, size: 72, color: Colors.blue[400]),
                const SizedBox(height: 16),
                const Text(
                  'زیادکردنی بەکارهێنەری نوێ',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'ناوی بەکارهێنەر',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'تکایە ناوی بەکارهێنەر بنووسە'
                      : null,
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'وشەی نهێنی',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'وشەی نهێنی پێویستە کەمتر نەبێت لە ٦ پیت'
                      : null,
                ),
                const SizedBox(height: 20),

                // Role Selector (only for admins)
                if (canChooseRole)
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(
                        value: 'user',
                        child: Text('بەکارهێنەر'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('ئەدمین')),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedRole = value ?? 'user'),
                    decoration: InputDecoration(
                      labelText: 'ڕۆڵ',
                      prefixIcon: const Icon(Icons.people_alt_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _addUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'زیادکردنی بەکارهێنەر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newUser = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text, // TODO: hash in production
        'role': (widget.currentUserRole == 'admin') ? _selectedRole : 'user',
        'createdAt': DateTime.now().toIso8601String(),
      };

      widget.onUserAdded(newUser);
      Navigator.pop(context);
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
