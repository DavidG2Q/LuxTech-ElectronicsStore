import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show User, AuthProvider;
import '../../models/user.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:shared_preferences/shared_preferences.dart';

class ManageUsersScreen extends StatefulWidget {
  static const routeName = '/manage-users';

  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  // Sample users data
  final List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    print('Loading users in ManageUsersScreen...');
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final users = await authProvider.getAllUsers();
    
    print('Received ${users.length} users from AuthProvider');
    for (var user in users) {
      print('User: ${user.name} (${user.email})');
    }

    setState(() {
      _users.clear();
      _users.addAll(users);
      _isLoading = false;
    });
  }

  void _toggleUserBlock(String userId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userIndex = _users.indexWhere((user) => user.id == userId);
    
    if (userIndex != -1) {
      final user = _users[userIndex];
      final updatedUser = User(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        registrationDate: user.registrationDate,
        isBlocked: !user.isBlocked,
        lastSignIn: user.lastSignIn,
      );

      setState(() => _users[userIndex] = updatedUser);

      if (updatedUser.isBlocked) {
        authProvider.blockUser(user.email);
      } else {
        authProvider.unblockUser(user.email);
      }
    }
  }

  // Method to clear all user data from SharedPreferences
  Future<void> _clearAllUserData() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear All User Data?'),
          content: const Text(
            'This will remove all locally stored user data. This action cannot be undone.',
            style: TextStyle(color: Colors.red),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Clear all user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('registered_emails');
      await prefs.remove('registered_names');
      await prefs.remove('registered_phones');
      await prefs.remove('registered_dates');
      
      // Also clear last sign-in times, but not blocked users
      await prefs.remove('auth_last_sign_in_times');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All user data has been cleared')),
      );
      
      // Reload the screen
      _loadUsers();
    } catch (e) {
      print('Error clearing user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync blocked status with auth provider
    final authProvider = Provider.of<AuthProvider>(context);
    final blockedEmails = authProvider.blockedUsers;  

    // Update local user list based on auth provider's blocked users
    final updatedUsers = _users.map((user) {
      // Skip admin user (case insensitive)
      if (user.email.toLowerCase() == 'admin@admin.com'.toLowerCase()) {
        return null;
      }
      
      if (blockedEmails.contains(user.email) && !user.isBlocked) {
        return User(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          registrationDate: user.registrationDate,
          isBlocked: true,
          lastSignIn: user.lastSignIn,
        );
      } else if (!blockedEmails.contains(user.email) && user.isBlocked) {
        return User(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          registrationDate: user.registrationDate,
          isBlocked: false,
          lastSignIn: user.lastSignIn,
        );
      }
      return user;
    }).where((user) => user != null).cast<User>().toList();

    if (!listEquals(updatedUsers, _users)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _users.clear();
          _users.addAll(updatedUsers);
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (ctx, index) {
                      final user = _users[index];
                      
                      // Skip admin user (case insensitive)
                      if (user.email.toLowerCase() == 'admin@admin.com'.toLowerCase()) {
                        return const SizedBox.shrink();
                      }
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).primaryColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.email_outlined, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Phone: ${user.phone}',
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Registered: ${user.registrationDate.day}/${user.registrationDate.month}/${user.registrationDate.year}',
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (user.lastSignIn != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_outlined, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Last Sign In: ${user.lastSignIn!.day}/${user.lastSignIn!.month}/${user.lastSignIn!.year} at ${user.lastSignIn!.hour > 12 ? user.lastSignIn!.hour - 12 : user.lastSignIn!.hour}:${user.lastSignIn!.minute.toString().padLeft(2, '0')} ${user.lastSignIn!.hour >= 12 ? 'PM' : 'AM'}',
                                                style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (user.isBlocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Blocked',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _toggleUserBlock(user.id),
                                  icon: Icon(
                                    user.isBlocked ? Icons.lock_open_outlined : Icons.lock_outline,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    user.isBlocked ? 'Unblock User' : 'Block User',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: user.isBlocked ? Colors.green : Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
