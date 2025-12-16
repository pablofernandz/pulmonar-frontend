import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _kJwt = 'jwt';
  static const _kRole = 'role';

  Future<void> setToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kJwt, token);
  }

  Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kJwt);
  }

  Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kJwt);
  }

  Future<void> setRole(String role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRole, role);
  }

  Future<String?> getRole() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRole);
  }

  Future<void> clearRole() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRole);
  }
}
