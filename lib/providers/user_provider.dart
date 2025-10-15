import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String street;
  final String building;
  final String city;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.street,
    required this.building,
    required this.city,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'street': street,
    'building': building,
    'city': city,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    street: json['street'] ?? '',
    building: json['building'] ?? '',
    city: json['city'] ?? '',
  );

  String get fullAddress => '$street, $building, $city';
}

class UserProvider with ChangeNotifier {
  UserProfile? _userProfile;
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  bool _userDeleted = false;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  bool get userDeleted => _userDeleted;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String street,
    required String building,
    required String city,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Validate input
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Invalid email address');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      if (name.isEmpty) {
        throw Exception('Name is required');
      }
      if (phone.isEmpty) {
        throw Exception('Phone number is required');
      }
      if (street.isEmpty || building.isEmpty || city.isEmpty) {
        throw Exception('Complete address is required');
      }

      // First create the auth user and pass profile data as metadata
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'street': street,
          'building': building,
          'city': city,
        },
      );

      if (res.user == null) {
        throw Exception('Failed to create user account');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Registration error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await loadUserProfile();
      }
    } catch (error) {
      debugPrint('Error signing in: $error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _userProfile = null;
    _userDeleted = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? street,
    String? building,
    String? city,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Only include fields that are being updated
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (street != null) updates['street'] = street;
      if (building != null) updates['building'] = building;
      if (city != null) updates['city'] = city;

      // Update profile in Supabase
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // Update local profile state
      if (_userProfile != null) {
        _userProfile = UserProfile(
          id: _userProfile!.id,
          email: _userProfile!.email,
          name: name ?? _userProfile!.name,
          phone: phone ?? _userProfile!.phone,
          street: street ?? _userProfile!.street,
          building: building ?? _userProfile!.building,
          city: city ?? _userProfile!.city,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveUserProfile() async {
    try {
      if (_userProfile != null) {
        if (_supabase.auth.currentUser == null) {
          throw Exception('Cannot save profile: User not authenticated');
        }

        final userId = _supabase.auth.currentUser!.id;

        if (_userProfile!.id != userId) {
          throw Exception('Profile ID does not match authenticated user ID');
        }

        await _supabase.from('profiles').upsert({
          'id': userId,
          'email': _userProfile!.email,
          'name': _userProfile!.name,
          'phone': _userProfile!.phone,
          'street': _userProfile!.street,
          'building': _userProfile!.building,
          'city': _userProfile!.city,
        });
      }
    } catch (error) {
      debugPrint('Error saving user profile: $error');
      rethrow;
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      _userProfile = UserProfile(
        id: user.id,
        email: data['email'] as String,
        name: data['name'] as String,
        phone: data['phone'] as String,
        street: data['street'] as String,
        building: data['building'] as String,
        city: data['city'] as String,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Save user details to local storage (shared_preferences)
  Future<void> saveUserToPrefs({required bool rememberMe}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_userProfile != null) {
      await prefs.setString('user_email', _userProfile!.email);
      await prefs.setString('user_name', _userProfile!.name);
      await prefs.setString('user_phone', _userProfile!.phone);
      await prefs.setString('user_street', _userProfile!.street);
      await prefs.setString('user_building', _userProfile!.building);
      await prefs.setString('user_city', _userProfile!.city);
      await prefs.setBool('remember_me', rememberMe);
    }
  }

  /// Load user details from local storage (shared_preferences)
  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final name = prefs.getString('user_name');
    final phone = prefs.getString('user_phone');
    final street = prefs.getString('user_street');
    final building = prefs.getString('user_building');
    final city = prefs.getString('user_city');
    if (email != null && name != null && phone != null && street != null && building != null && city != null) {
      _userProfile = UserProfile(
        id: '', // ID is not stored locally
        email: email,
        name: name,
        phone: phone,
        street: street,
        building: building,
        city: city,
      );
      notifyListeners();
    }
  }

  /// Clear user details from local storage (shared_preferences)
  Future<void> clearUserData({bool preserveEmail = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = preserveEmail ? prefs.getString('user_email') : null;
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_street');
    await prefs.remove('user_building');
    await prefs.remove('user_city');
    await prefs.remove('remember_me');
    if (!preserveEmail) {
      await prefs.remove('user_email');
    } else if (email != null) {
      await prefs.setString('user_email', email);
    }
    _userProfile = null;
    notifyListeners();
  }

  /// Check if Remember Me was selected
  Future<bool> isRememberMeSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }
}
