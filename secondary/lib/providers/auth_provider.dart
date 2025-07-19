import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/user.dart' as app_user;


class UnverifiedEmailError implements Exception {
  @override
  String toString() => 'UNVERIFIED_EMAIL';
}

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _name;
  String? _email;
  String? _street;
  String? _building;
  String? _city;
  String? _phone;
  DateTime? _expiryDate;
  bool _isRemembered = false;
  
  // List of blocked users - Local functionality only
  // This blocks users only in the current app installation and persists across app restarts
  // When a user is blocked, they can't log in to this device, but their Supabase account remains active
  // Clearing app data will remove all block records
  final List<String> _blockedUsers = [];
  // Map to store last sign-in times
  final Map<String, DateTime> _lastSignInTimes = {};

  // Keys for SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _nameKey = 'auth_name';
  static const String _emailKey = 'auth_email';
  static const String _streetKey = 'auth_street';
  static const String _buildingKey = 'auth_building';
  static const String _cityKey = 'auth_city';
  static const String _phoneKey = 'auth_phone';
  static const String _expiryDateKey = 'auth_expiry_date';
  static const String _isRememberedKey = 'auth_is_remembered';
  static const String _blockedUsersKey = 'auth_blocked_users';
  static const String _lastSignInTimesKey = 'auth_last_sign_in_times';
  
  // Keys for registered users
  static const String _registeredUsersKey = 'registered_users';
  static const String _registeredEmailsKey = 'registered_emails';
  static const String _registeredNamesKey = 'registered_names';
  static const String _registeredPhonesKey = 'registered_phones';
  static const String _registeredDatesKey = 'registered_dates';
  
  // Keys for user metadata
  static const String _userMetadataKey = 'user_metadata';

  // Just one key for remembered email
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _lastPasswordKey = 'last_password';

  // Get Supabase client
  final supabase = Supabase.instance.client;

  // Getters
  String? get street => _street;
  String? get building => _building;
  String? get city => _city;
  String? get phone => _phone;
  String? get name => _name;
  String? get email => _email;
  String? get userId => _userId;
  String? get token {
    if (_expiryDate != null &&
        _expiryDate!.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }
  bool get isAuth => token != null;
  bool get isRemembered => _isRemembered;
  List<String> get blockedUsers => [..._blockedUsers];

  // Get full address
  String? get address {
    if (_street == null || _city == null) return null;
    return '$_street, ${_building != null ? 'building $_building, ' : ''}$_city';
  }

  // Initialize auth state from Supabase and SharedPreferences
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load blocked users
    if (prefs.containsKey(_blockedUsersKey)) {
      final blockedUsersList = prefs.getStringList(_blockedUsersKey) ?? [];
      _blockedUsers.clear();
      _blockedUsers.addAll(blockedUsersList);
    }
    
    // Load last sign-in times
    await _loadLastSignInTimes();
    
    try {
      // First try to restore from SharedPreferences
      final savedToken = prefs.getString(_tokenKey);
      final savedUserId = prefs.getString(_userIdKey);
      final savedEmail = prefs.getString(_emailKey);
      
      if (savedToken != null && savedUserId != null && savedEmail != null) {
        // Check if user is blocked locally - case insensitive check
        if (_blockedUsers.contains(savedEmail.toLowerCase())) {
          // User is blocked locally, don't allow auto-login
          print('Auto-login blocked for locally blocked user: $savedEmail');
          await _clearAuthData(); // Clear saved auth data
          return;
        }
        
        _token = savedToken;
        _userId = savedUserId;
        _name = prefs.getString(_nameKey);
        _email = savedEmail;
        _street = prefs.getString(_streetKey);
        _building = prefs.getString(_buildingKey);
        _city = prefs.getString(_cityKey);
        _phone = prefs.getString(_phoneKey);
        _expiryDate = DateTime.now().add(const Duration(hours: 1));
        _isRemembered = true;
        notifyListeners();
      }
      
      // Then try Supabase if online
      try {
        final session = supabase.auth.currentSession;
        final user = supabase.auth.currentUser;
        
        if (session != null && user != null) {
          // Check if user is blocked locally
          if (user.email != null && _blockedUsers.contains(user.email!.toLowerCase())) {
            // Only sign out locally, not from Supabase
            clearLocalStateOnly();
            return;
          }
          
          try {
            // Get user profile from Supabase profiles table
            final profile = await supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();
            
            // Update local state with Supabase profile data
            _token = session.accessToken;
            _userId = user.id;
            _name = profile['name']?.toString().isNotEmpty == true ? profile['name'] : 'User';
            _email = user.email;
            _street = profile['street']?.toString().isNotEmpty == true ? profile['street'] : '';
            _building = profile['building']?.toString().isNotEmpty == true ? profile['building'] : '';
            _city = profile['city']?.toString().isNotEmpty == true ? profile['city'] : '';
            _phone = profile['phone']?.toString().isNotEmpty == true ? profile['phone']?.toString() : '';
            _expiryDate = DateTime.now().add(const Duration(hours: 1));
            _isRemembered = true;
            
            // Save to SharedPreferences
            await _saveAuthData();
            
            notifyListeners();
          } catch (e) {
            print('Error fetching profile: ${e.toString()}');
            // Keep using SharedPreferences data if Supabase fetch fails
          }
        }
      } catch (e) {
        print('Error checking Supabase session: ${e.toString()}');
        // Keep using SharedPreferences data if Supabase check fails
      }
    } catch (e) {
      print('Error in tryAutoLogin: ${e.toString()}');
    }
  }

  // Simple method to save remembered email
  Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_isRemembered) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  // Method to get remembered email
  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey);
  }

  // Clear remembered email
  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
    _isRemembered = false;
    notifyListeners();
  }

  // Add this method to save credentials locally
  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
    await prefs.setString(_lastPasswordKey, password);
  }

  // Add this method to get saved credentials
  Future<Map<String, String?>> _getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_rememberedEmailKey),
      'password': prefs.getString(_lastPasswordKey),
    };
  }

  // Add this method to clear saved credentials
  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPasswordKey);
  }

  // Modify login method to save credentials
  Future<bool> login(String email, String password, [bool rememberMe = false]) async {
    try {
      // 1. First check if user is blocked locally - ensure lowercase comparison for case insensitivity
      final normalizedEmail = email.trim().toLowerCase();
      if (_blockedUsers.contains(normalizedEmail)) {
        throw Exception('blocked');
      }

      // 2. Try login with Supabase
      try {
        final response = await supabase.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        
        if (response.user == null) {
          throw Exception('Invalid email or password');
        }

        // Check if profile exists, if not create it
        try {
          var profile;
          try {
            profile = await supabase
              .from('profiles')
              .select()
              .eq('id', response.user!.id)
              .single();
          } catch (e) {
            // Profile doesn't exist, create it
            final displayName = response.user!.email?.split('@')[0] ?? 'User';
            
            try {
              await supabase.from('profiles').insert({
                'id': response.user!.id,
                'name': displayName,
                'email': response.user!.email,
                'phone': '',
                'street': '',
                'building': '',
                'city': '',
              });
              
              // Now fetch the newly created profile
              profile = await supabase
                .from('profiles')
                .select()
                .eq('id', response.user!.id)
                .single();
            } catch (insertError) {
              // Even if profile creation fails, continue with login
              profile = {
                'name': displayName,
                'email': response.user!.email,
                'phone': '',
                'street': '',
                'building': '',
                'city': '',
              };
            }
          }

          // Extract phone from profile
          String phoneFromProfile = 'Not provided';
          if (profile.containsKey('phone') && profile['phone'] != null && profile['phone'].toString().isNotEmpty) {
            phoneFromProfile = profile['phone'].toString();
          }

          // Update local state with profile data
          _token = response.session?.accessToken;
          _userId = response.user!.id;
          _name = profile['name']?.toString().isNotEmpty == true ? profile['name'] : 'User';
          _email = response.user!.email;
          _street = profile['street']?.toString().isNotEmpty == true ? profile['street'] : '';
          _building = profile['building']?.toString().isNotEmpty == true ? profile['building'] : '';
          _city = profile['city']?.toString().isNotEmpty == true ? profile['city'] : '';
          _phone = phoneFromProfile;
          _expiryDate = DateTime.now().add(const Duration(hours: 1));
          _isRemembered = rememberMe;

          // Save auth data
          await _saveAuthData();
          _lastSignInTimes[normalizedEmail] = DateTime.now();
          await _saveLastSignInTimes();
          
          // Make sure this user is in the registered users lists
          final prefs = await SharedPreferences.getInstance();
          final registeredEmails = prefs.getStringList(_registeredEmailsKey) ?? [];
          
          // Only add if not already in the list
          if (!registeredEmails.contains(normalizedEmail) && normalizedEmail != 'admin@admin.com'.toLowerCase()) {
            final registeredNames = prefs.getStringList(_registeredNamesKey) ?? [];
            final registeredPhones = prefs.getStringList(_registeredPhonesKey) ?? [];
            final registeredDates = prefs.getStringList(_registeredDatesKey) ?? [];
            
            registeredEmails.add(normalizedEmail);
            registeredNames.add(_name ?? 'User');
            registeredPhones.add(phoneFromProfile);
            registeredDates.add(DateTime.now().millisecondsSinceEpoch.toString());
            
            await prefs.setStringList(_registeredEmailsKey, registeredEmails);
            await prefs.setStringList(_registeredNamesKey, registeredNames);
            await prefs.setStringList(_registeredPhonesKey, registeredPhones);
            await prefs.setStringList(_registeredDatesKey, registeredDates);
          } else if (registeredEmails.contains(normalizedEmail)) {
            // Update the existing user's phone number if needed
            final index = registeredEmails.indexOf(normalizedEmail);
            final registeredPhones = prefs.getStringList(_registeredPhonesKey) ?? [];
            if (index < registeredPhones.length) {
              final currentPhone = registeredPhones[index];
              if (currentPhone == 'No phone' || currentPhone == 'Not provided') {
                final phoneValue = _phone ?? '';
                if (phoneValue.isNotEmpty) {
                  registeredPhones[index] = phoneValue;
                  await prefs.setStringList(_registeredPhonesKey, registeredPhones);
                }
              }
            }
          }
        
          notifyListeners();
          return true;
        } catch (e) {
          throw Exception('Error handling user profile');
        }

      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('email not confirmed') || 
            errorStr.contains('email_confirmation_required') ||
            errorStr.contains('email_confirmation')) {
          throw UnverifiedEmailError();
        }
        
        if (errorStr.contains('invalid login credentials') || 
            errorStr.contains('invalid email or password') ||
            errorStr.contains('invalid_grant')) {
          throw Exception('Invalid email or password');
        }
        
        throw Exception('Login failed: $errorStr');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(
    String name,
    String email,
    String password, {
    String? street,
    String? building,
    String? city,
    String? phone,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'street': street,
          'building': building,
          'city': city,
          'phone': phone,
        },
      );
      
      if (response.user == null) {
        throw Exception('Registration failed: No user returned');
      }
      
      // 2. Create profile in profiles table with retries
      int maxRetries = 3;
      int currentTry = 0;
      bool profileCreated = false;
      
      while (currentTry < maxRetries && !profileCreated) {
        try {
          print('Attempting profile creation (attempt ${currentTry + 1})');
          // First check if profile exists
          final existingProfile = await supabase
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();
          if (existingProfile == null) {
            // Profile doesn't exist, create it
            final profileData = {
              'id': response.user!.id,
              'name': name,
              'email': email,
              'street': street ?? '',
              'building': building ?? '',
              'city': city ?? '',
              'phone': phone ?? ''
            };
            await supabase
              .from('profiles')
              .insert(profileData)
              .select()
              .single();
          } else {
            // Profile exists, update it
            await supabase
              .from('profiles')
              .update({
                'name': name,
                'email': email,
                'street': street ?? '',
                'building': building ?? '',
                'city': city ?? '',
                'phone': phone ?? ''
              })
              .eq('id', response.user!.id)
              .select()
              .single();
          }
          profileCreated = true;
          print('Profile created/updated successfully');
        } catch (e) {
          print('Profile creation error (attempt ${currentTry + 1}): ${e.toString()}');
          // If the error is a permissions/RLS error, break and consider registration successful
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('row-level security') || errStr.contains('permission denied') || errStr.contains('42501')) {
            print('Profile creation failed due to RLS/permissions, but user is created. Continuing registration.');
            break;
          }
          currentTry++;
          if (currentTry >= maxRetries) {
            throw Exception('Failed to create profile after $maxRetries attempts');
          }
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      
      // 3. Save to local storage
      final prefs = await SharedPreferences.getInstance();
      final normalizedEmail = email.trim().toLowerCase();
      
      // Save basic user info
      await prefs.setString(_nameKey, name);
      await prefs.setString(_emailKey, email);
      await prefs.setString(_streetKey, street ?? '');
      await prefs.setString(_buildingKey, building ?? '');
      await prefs.setString(_cityKey, city ?? '');
      await prefs.setString(_phoneKey, phone ?? '');
      
      // Add to registered users list
      final registeredEmails = prefs.getStringList(_registeredEmailsKey) ?? [];
      if (!registeredEmails.contains(normalizedEmail)) {
        final registeredNames = prefs.getStringList(_registeredNamesKey) ?? [];
        final registeredPhones = prefs.getStringList(_registeredPhonesKey) ?? [];
        final registeredDates = prefs.getStringList(_registeredDatesKey) ?? [];
        
        registeredEmails.add(normalizedEmail);
        registeredNames.add(name);
        registeredPhones.add(phone ?? 'Not provided');
        registeredDates.add(DateTime.now().millisecondsSinceEpoch.toString());
        
        await prefs.setStringList(_registeredEmailsKey, registeredEmails);
        await prefs.setStringList(_registeredNamesKey, registeredNames);
        await prefs.setStringList(_registeredPhonesKey, registeredPhones);
        await prefs.setStringList(_registeredDatesKey, registeredDates);
      }
      
      print('Registration completed successfully');
      
    } catch (e) {
      print('Registration error: ${e.toString()}');
      
      // Check for specific error messages
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('already exists') || 
          errorMsg.contains('already registered') ||
          errorMsg.contains('already in use')) {
        throw Exception('An account with this email already exists');
      }
      
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<void> updateProfile(
    String name,
    String email, {
    String? street,
    String? building,
    String? city,
    String? phone,
  }) async {
    try {
      // Get current user from Supabase
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please log in again.');
      }

      print('Updating profile for user ${user.id}');
      print('New data: name=$name, email=$email, street=$street, building=$building, city=$city, phone=$phone');

      // Update profiles table directly
      final response = await supabase
        .from('profiles')
        .update({
          'name': name,
          'email': email,  // Note: This should match auth.users email
          'street': street ?? '',
          'building': building ?? '',
          'city': city ?? '',
          'phone': phone ?? '',
        })
        .eq('id', user.id)
        .select()
        .single();
      
      print('Profile update response: $response');

      // Update local state
      _name = name;
      _email = email;
      _street = street;
      _building = building;
      _city = city;
      _phone = phone ?? '';

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, name);
      await prefs.setString(_emailKey, email);
      await prefs.setString(_streetKey, street ?? '');
      await prefs.setString(_buildingKey, building ?? '');
      await prefs.setString(_cityKey, city ?? '');
      await prefs.setString(_phoneKey, phone ?? '');
      
      // Update phone in registered users list
      final normalizedEmail = email.toLowerCase();
      final registeredEmails = prefs.getStringList(_registeredEmailsKey) ?? [];
      
      if (registeredEmails.contains(normalizedEmail)) {
        final index = registeredEmails.indexOf(normalizedEmail);
        final registeredPhones = prefs.getStringList(_registeredPhonesKey) ?? [];
        
        if (index < registeredPhones.length) {
          // Update phone for this user
          String phoneToSave = 'Not provided';
          if (phone != null && phone.isNotEmpty) {
            phoneToSave = phone;
          }
          registeredPhones[index] = phoneToSave;
          await prefs.setStringList(_registeredPhonesKey, registeredPhones);
          print('Updated phone in registered users list: $phoneToSave');
        }
      }
      
      notifyListeners();
      
    } catch (e) {
      print('Update profile error: ${e.toString()}');
      if (e.toString().contains('row-level security policy')) {
        throw Exception('Permission denied. Please make sure you are logged in and try again.');
      }
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> blockUser(String email) async {
    // Normalize email to lowercase for consistent checks
    final normalizedEmail = email.toLowerCase();
    
    if (!_blockedUsers.contains(normalizedEmail)) {
      _blockedUsers.add(normalizedEmail);
      await _saveBlockedUsers();
      
      // If this is the currently logged in user, log them out
      if (_email != null && _email!.toLowerCase() == normalizedEmail) {
        // First try to sign out from Supabase (but don't wait for it)
        supabase.auth.signOut().catchError((e) {
          print('Error signing out from Supabase: ${e.toString()}');
        });
        
        // Clear local state (this triggers UI update)
        clearLocalStateOnly();
        
        // Clear auth data in SharedPreferences (this ensures they can't auto-login)
        await _clearAuthData();
        
        // Also clear any saved credentials for this user
        await _clearSavedCredentials();
      }
      
      // Update last sign in time to show when they were blocked
      _lastSignInTimes[normalizedEmail] = DateTime.now();
      await _saveLastSignInTimes();
      
      notifyListeners();
    }
  }

  Future<void> unblockUser(String email) async {
    // Normalize email to lowercase for consistent checks
    final normalizedEmail = email.toLowerCase();
    
    if (_blockedUsers.contains(normalizedEmail)) {
      _blockedUsers.remove(normalizedEmail);
      await _saveBlockedUsers();
      
      // Update last sign in time to show when they were unblocked
      _lastSignInTimes[normalizedEmail] = DateTime.now();
      await _saveLastSignInTimes();
      
      notifyListeners();
    }
  }

  // Add a method to check if a user is blocked
  bool isUserBlocked(String email) {
    final normalizedEmail = email.toLowerCase();
    return _blockedUsers.contains(normalizedEmail);
  }

  // Clear only local state variables without async operations
  // This is useful for immediate UI response when logging out
  void clearLocalStateOnly() {
    _token = null;
    _userId = null;
    _name = null;
    _email = null;
    _street = null;
    _building = null;
    _city = null;
    _phone = null;
    _expiryDate = null;
    // Note: We don't clear _blockedUsers as this is persisted locally
    // and should be maintained even when the user logs out
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      // Clear local state first (this makes UI response immediate)
      clearLocalStateOnly();
      
      // Then handle background tasks without blocking UI
      await Future.wait([
        // Try to sign out from Supabase
        Future(() async {
          try {
            await supabase.auth.signOut();
          } catch (e) {
            print('Error signing out from Supabase: ${e.toString()}');
          }
        }),
        
        // Clear saved auth data and credentials
        _clearAuthData(),
        _clearSavedCredentials(),
      ]);
    } catch (e) {
      print('Error during logout: ${e.toString()}');
    }
  }

  // Save auth data to SharedPreferences
  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_token != null) {
      prefs.setString(_tokenKey, _token!);
    }
    
    if (_userId != null) {
      prefs.setString(_userIdKey, _userId!);
    }
    
    if (_name != null) {
      prefs.setString(_nameKey, _name!);
    }
    
    if (_email != null) {
      prefs.setString(_emailKey, _email!);
    }
    
    if (_street != null) {
      prefs.setString(_streetKey, _street!);
    }
    
    if (_building != null) {
      prefs.setString(_buildingKey, _building!);
    }
    
    if (_city != null) {
      prefs.setString(_cityKey, _city!);
    }
    
    if (_phone != null) {
      prefs.setString(_phoneKey, _phone!);
    }
    
    if (_expiryDate != null) {
      prefs.setInt(_expiryDateKey, _expiryDate!.millisecondsSinceEpoch);
    }
    
    prefs.setBool(_isRememberedKey, _isRemembered);
  }
  
  // Save blocked users to SharedPreferences
  Future<void> _saveBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    // Make sure all blocked users are stored in lowercase for consistent checks
    final normalizedBlockedUsers = _blockedUsers.map((email) => email.toLowerCase()).toList();
    await prefs.setStringList(_blockedUsersKey, normalizedBlockedUsers);
    print('Saved blocked users: $normalizedBlockedUsers');
  }

  // Clear auth data from SharedPreferences
  // Note: This doesn't clear blocked users as they are maintained locally
  // even when the user logs out
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    
    prefs.remove(_tokenKey);
    prefs.remove(_userIdKey);
    prefs.remove(_nameKey);
    prefs.remove(_emailKey);
    prefs.remove(_streetKey);
    prefs.remove(_buildingKey);
    prefs.remove(_cityKey);
    prefs.remove(_phoneKey);
    prefs.remove(_expiryDateKey);
    prefs.remove(_isRememberedKey);
    // Do NOT clear _rememberedEmailKey here; only clear it if the user unchecks 'Remember me'.
    // Don't clear blocked users when logging out
  }

  // Add method to save last sign-in times
  Future<void> _saveLastSignInTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final timesMap = _lastSignInTimes.map(
      (email, time) => MapEntry(email, time.toIso8601String())
    );
    await prefs.setString(_lastSignInTimesKey, jsonEncode(timesMap));
  }

  // Add method to load last sign-in times
  Future<void> _loadLastSignInTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final timesJson = prefs.getString(_lastSignInTimesKey);
    if (timesJson != null) {
      final timesMap = Map<String, dynamic>.from(jsonDecode(timesJson) as Map);
      _lastSignInTimes.clear();
      timesMap.forEach((email, timeStr) {
        _lastSignInTimes[email] = DateTime.parse(timeStr as String);
      });
    }
  }

  // Get all users
  Future<List<app_user.User>> getAllUsers() async {
    List<app_user.User> users = [];
    try {
      print('Debug - Starting getAllUsers');
      
      // Get local data
      final prefs = await SharedPreferences.getInstance();
      final registeredEmails = prefs.getStringList(_registeredEmailsKey) ?? [];
      final registeredNames = prefs.getStringList(_registeredNamesKey) ?? [];
      final registeredPhones = prefs.getStringList(_registeredPhonesKey) ?? [];
      final registeredDates = prefs.getStringList(_registeredDatesKey) ?? [];

      print('Debug - Local registered emails: $registeredEmails');
      print('Debug - Blocked users: $_blockedUsers');
      print('Debug - Users who have logged in: ${_lastSignInTimes.keys.toList()}');
      
      // Add users from _lastSignInTimes who might not be in registeredEmails
      // This ensures we show all users who have logged in locally
      for (final email in _lastSignInTimes.keys) {
        final normalizedEmail = email.toLowerCase();
        // Skip admin user
        if (normalizedEmail == 'admin@admin.com'.toLowerCase()) continue;
        
        // Only add if not already in registeredEmails list
        if (!registeredEmails.contains(normalizedEmail)) {
          registeredEmails.add(normalizedEmail);
          registeredNames.add(email.split('@')[0]); // Use part of email as name
          registeredPhones.add('No phone');
          registeredDates.add(_lastSignInTimes[email]!.millisecondsSinceEpoch.toString());
          
          // Save updated lists
          await prefs.setStringList(_registeredEmailsKey, registeredEmails);
          await prefs.setStringList(_registeredNamesKey, registeredNames);
          await prefs.setStringList(_registeredPhonesKey, registeredPhones);
          await prefs.setStringList(_registeredDatesKey, registeredDates);
          
          print('Debug - Added user from login history: $email');
        }
      }

      // Process each registered user
      for (var i = 0; i < registeredEmails.length; i++) {
        final email = registeredEmails[i].toLowerCase();
        // Skip admin user (case insensitive)
        if (email == 'admin@admin.com'.toLowerCase()) continue;
        
        // Get user data from local storage
        final name = i < registeredNames.length ? registeredNames[i] : 'User ${i + 1}';
        
        // Handle phone data
        String phone = 'Not provided';
        if (i < registeredPhones.length) {
          final phoneValue = registeredPhones[i];
          if (phoneValue.isNotEmpty && phoneValue != 'No phone' && phoneValue != 'Not provided') {
            phone = phoneValue;
          }
        }
        
        // Get registration date
        DateTime registrationDate;
        try {
          registrationDate = i < registeredDates.length 
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(registeredDates[i]))
            : DateTime.now();
        } catch (e) {
          registrationDate = DateTime.now();
        }

        // Get last sign in time
        final lastSignIn = _lastSignInTimes[email];

        print('Debug - Adding user: $email, name: $name, blocked: ${_blockedUsers.contains(email)}');

        users.add(app_user.User(
          id: 'user_$i',
          name: name,
          email: email,
          phone: phone,
          registrationDate: registrationDate,
          isBlocked: _blockedUsers.contains(email),
          lastSignIn: lastSignIn,
        ));
      }

      // Sort users by last sign in time (most recent first)
      users.sort((a, b) {
        if (a.lastSignIn == null && b.lastSignIn == null) return 0;
        if (a.lastSignIn == null) return 1;
        if (b.lastSignIn == null) return -1;
        return b.lastSignIn!.compareTo(a.lastSignIn!);
      });

      print('Debug - Final user count: ${users.length}');
    } catch (e) {
      print('Error fetching users: ${e.toString()}');
    }
    
    return users;
  }

  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://luxetreset.vercel.app',
      );
    } catch (e) {
      print('Reset password error: ${e.toString()}');
      throw Exception('Failed to send reset link: ${e.toString()}');
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      print('Resend verification email error: ${e.toString()}');
      throw Exception('Failed to resend verification email: ${e.toString()}');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      print('Update password error: ${e.toString()}');
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  // Add method to refresh user data from Supabase
  Future<void> refreshUserData() async {
    try {
      print('Starting user data refresh...');
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        throw Exception('No authenticated user found');
      }
      print('Current user: ${user.email}');

      // Get user profile from Supabase profiles table
      print('Fetching profile from Supabase...');
      final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
      
      print('Profile data received: $profile');
      
      // Update local state with Supabase profile data
      _name = profile['name']?.toString().isNotEmpty == true ? profile['name'] : 'User';
      _email = user.email;
      _street = profile['street']?.toString().isNotEmpty == true ? profile['street'] : '';
      _building = profile['building']?.toString().isNotEmpty == true ? profile['building'] : '';
      _city = profile['city']?.toString().isNotEmpty == true ? profile['city'] : '';
      _phone = profile['phone']?.toString().isNotEmpty == true ? profile['phone']?.toString() : '';
      
      print('Local state updated:');
      print('Name: $_name');
      print('Email: $_email');
      print('Street: $_street');
      print('Building: $_building');
      print('City: $_city');
      print('Phone: $_phone');
      
      // Save to SharedPreferences
      print('Saving to SharedPreferences...');
      await _saveAuthData();
      print('Saved to SharedPreferences successfully');
      
      // Refresh products data
      print('Refreshing products data...');
      await _refreshProductsData();
      
      print('Notifying listeners...');
      notifyListeners();
      print('User data refresh completed successfully');
    } catch (e) {
      print('Error refreshing user data: ${e.toString()}');
      throw Exception('Failed to refresh user data: ${e.toString()}');
    }
  }

  // Add method to refresh products data
  Future<void> _refreshProductsData() async {
    try {
      print('Fetching products from Supabase...');
      // Get all products from Supabase with their flags
      final products = await supabase
        .from('products')
        .select('*, is_new, is_featured');
      
      print('Products fetched from Supabase: ${products.length} items');
      
      if (products.isEmpty) {
        print('No products found in Supabase, checking local storage...');
        // If Supabase is empty, try to get from local storage
        final prefs = await SharedPreferences.getInstance();
        final localProductsJson = prefs.getString('products_data');
        
        if (localProductsJson != null) {
          print('Found products in local storage');
          return; // Keep using local storage data
        }
        
        print('No products found in local storage either');
        // Only use hardcoded products if both Supabase and local storage are empty
        return;
      }
      
      // Process products to ensure flags are correct
      final processedProducts = products.map((product) {
        // Ensure boolean flags are properly set
        return {
          ...product,
          'is_new': product['is_new'] == true,
          'is_featured': product['is_featured'] == true,
        };
      }).toList();
      
      // Save products to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('products_data', jsonEncode(processedProducts));
      
      print('Products data saved to SharedPreferences with updated flags');
    } catch (e) {
      print('Error refreshing products data: ${e.toString()}');
      // Don't throw here, as we want the user refresh to continue even if products refresh fails
    }
  }

  // Add this method to ensure profile exists after email verification
  Future<void> ensureProfileExists() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Check if profile exists
      final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

      if (profile == null) {
        // Profile doesn't exist, create it
        final prefs = await SharedPreferences.getInstance();
        final userMetadataJson = prefs.getString('${_userMetadataKey}_${user.id}');
        Map<String, dynamic> userMetadata = {};
        
        if (userMetadataJson != null) {
          userMetadata = Map<String, dynamic>.from(
            jsonDecode(userMetadataJson) as Map
          );
        }

        await supabase.from('profiles').insert({
          'id': user.id,
          'name': userMetadata['name'] ?? _name ?? '',
          'email': user.email,
          'street': userMetadata['street'] ?? _street ?? '',
          'building': userMetadata['building'] ?? _building ?? '',
          'city': userMetadata['city'] ?? _city ?? '',
          'phone': userMetadata['phone'] ?? _phone ?? '',
        });
      }
    } catch (e) {
      print('Error ensuring profile exists: ${e.toString()}');
    }
  }
}
