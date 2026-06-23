import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiClient.post('/auth/login', {
        'email': email,
        'password': password,
      }, auth: false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await ApiClient.saveToken(data['access_token']);
        _user = UserModel.fromJson(data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['message'] ?? 'Помилка входу';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Помилка підключення до сервера';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.deleteToken();
    _user = null;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    try {
      final response = await ApiClient.get('/auth/me');
      if (response.statusCode == 200) {
        _user = UserModel.fromJson(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      _user = null;
      notifyListeners();
    }
  }
}
