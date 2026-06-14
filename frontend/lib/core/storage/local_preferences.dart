import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferences {
  const LocalPreferences._();

  static const _authTokenKey = 'mindvault.authToken';
  static const _workspaceViewKey = 'mindvault.workspaceView';
  static const _documentPanelOpenKey = 'mindvault.documentPanelOpen';

  static Future<String?> readAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  static Future<void> saveAuthToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_authTokenKey);
      return;
    }
    await prefs.setString(_authTokenKey, token);
  }

  static Future<String?> readWorkspaceView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workspaceViewKey);
  }

  static Future<void> saveWorkspaceView(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspaceViewKey, value);
  }

  static Future<bool?> readDocumentPanelOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_documentPanelOpenKey);
  }

  static Future<void> saveDocumentPanelOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_documentPanelOpenKey, value);
  }
}
