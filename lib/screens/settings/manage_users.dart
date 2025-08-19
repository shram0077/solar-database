import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function(List<Map<String, dynamic>>) onUsersUpdated;
  final String currentUserRole;

  const ManageUsersScreen({
    super.key,
    required this.users,
    required this.onUsersUpdated,
    required this.currentUserRole,
  });

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  late List<Map<String, dynamic>> _users;

  @override
  void initState() {
    super.initState();
    _users = List.from(widget.users);
  }

  Future<bool?> _confirmDelete() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteUser(int index) async {
    final confirmed = await _confirmDelete();
    if (confirmed == true) {
      setState(() {
        _users.removeAt(index);
      });
      widget.onUsersUpdated(_users);
    }
  }

  void _updateUserRole(int index, String newRole) {
    setState(() {
      _users[index]['role'] = newRole;
    });
    widget.onUsersUpdated(_users);
  }

  @override
  Widget build(BuildContext context) {
    final canManageUsers = widget.currentUserRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _users.isEmpty
          ? const Center(child: Text('No users found.'))
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // User Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['username'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(user['role']),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user['role'].toString().toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user['password'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action Menu
                        if (canManageUsers)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[600],
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteUser(index);
                              } else {
                                _updateUserRole(index, value);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'user',
                                child: Row(
                                  children: [
                                    Icon(Icons.person, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    const Text(' بکە بە بەکارهێنەر'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'admin',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(' بکە بە ئەدمین'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'سڕینەوەی بەکارهێنەر',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.green;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
