import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const baseUrl = 'https://YOUR_RAILWAY_URL'; // замени на свой URL
  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 15);

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> saveToken(String t) => _storage.write(key: 'token', value: t);
  static Future<void> deleteToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _headers())
        .timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _handle(r);
  }

  static dynamic _handle(http.Response r) {
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    throw ApiException(data['error'] ?? 'Ошибка сервера', r.statusCode);
  }

  // --- Auth ---
  static Future<void> sendOtp(String email) =>
      post('/api/auth/send-otp', {'email': email}, auth: false);

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final data = await post('/api/auth/verify-otp', {'email': email, 'code': code}, auth: false);
    return data as Map<String, dynamic>;
  }

  static Future<String> login(String email, String code) async {
    final data = await post('/api/auth/login', {'email': email, 'code': code}, auth: false);
    await saveToken(data['token']);
    return data['token'];
  }

  static Future<String> register(
      String email, String code, String username, String displayName) async {
    final data = await post('/api/auth/register', {
      'email': email,
      'code': code,
      'username': username,
      'displayName': displayName,
    }, auth: false);
    await saveToken(data['token']);
    return data['token'];
  }

  static Future<Map<String, dynamic>> getMe() async {
    final data = await get('/api/auth/me');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final data = await patch('/api/auth/me', {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return data as Map<String, dynamic>;
  }

  // --- Chats ---
  static Future<List<dynamic>> getChats() async {
    final data = await get('/api/chats');
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> openDirectChat(String targetUserId) async {
    final data = await post('/api/chats/direct', {'targetUserId': targetUserId});
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds) async {
    final data = await post('/api/chats/group', {'name': name, 'memberIds': memberIds});
    return data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMessages(String chatId, {String? before}) async {
    final q = before != null ? '?before=${Uri.encodeComponent(before)}' : '';
    final data = await get('/api/chats/$chatId/messages$q');
    return data as List<dynamic>;
  }

  static Future<List<dynamic>> searchUsers(String q) async {
    final data = await get('/api/chats/users/search?q=${Uri.encodeComponent(q)}');
    return data as List<dynamic>;
  }

  // --- Channels ---
  static Future<List<dynamic>> exploreChannels({String? q}) async {
    final qs = q != null ? '?q=${Uri.encodeComponent(q)}' : '';
    final data = await get('/api/channels/explore$qs');
    return data as List<dynamic>;
  }

  static Future<List<dynamic>> myChannels() async {
    final data = await get('/api/channels/my');
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getChannel(String username) async {
    final data = await get('/api/channels/$username');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> subscribeChannel(String channelId) async {
    final data = await post('/api/channels/$channelId/subscribe', {});
    return data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getChannelPosts(String channelId) async {
    final data = await get('/api/channels/$channelId/posts');
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createChannel(
      String username, String name, String? description) async {
    final data = await post('/api/channels', {
      'username': username,
      'name': name,
      if (description != null) 'description': description,
    });
    return data as Map<String, dynamic>;
  }

  // --- AI ---
  static Future<String> askAi(String chatId, String message) async {
    final data = await post('/api/ai/chat/$chatId', {
      'message': message,
      'includeHistory': true,
    });
    return data['response'] as String;
  }

  static Future<String> summarizeChat(String chatId) async {
    final data = await get('/api/ai/summarize/$chatId');
    return data['summary'] as String;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
