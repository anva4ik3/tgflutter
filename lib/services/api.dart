import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Замени на свой Railway URL
  static const baseUrl = 'https://tgback-production.up.railway.app';
  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 20);

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> saveToken(String t) => _storage.write(key: 'token', value: t);
  static Future<void> deleteToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _headers())
        .timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final r = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http
        .patch(Uri.parse('$baseUrl$path'),
            headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> delete(String path) async {
    final r = await http
        .delete(Uri.parse('$baseUrl$path'), headers: await _headers())
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

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async =>
      (await post('/api/auth/verify-otp', {'email': email, 'code': code}, auth: false))
          as Map<String, dynamic>;

  static Future<String> login(String email, String code) async {
    final data = await post('/api/auth/login', {'email': email, 'code': code}, auth: false);
    await saveToken(data['token']);
    return data['token'];
  }

  static Future<String> register(String email, String username, String displayName) async {
    final data = await post('/api/auth/register',
        {'email': email, 'username': username, 'displayName': displayName},
        auth: false);
    await saveToken(data['token']);
    return data['token'];
  }

  static Future<Map<String, dynamic>> getMe() async =>
      (await get('/api/auth/me')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName, String? bio, String? avatarUrl,
  }) async =>
      (await patch('/api/auth/me', {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      })) as Map<String, dynamic>;

  // --- Contacts ---
  static Future<List<dynamic>> getContacts() async =>
      (await get('/api/contacts')) as List<dynamic>;

  static Future<Map<String, dynamic>> addContact(String username, {String? nickname}) async =>
      (await post('/api/contacts', {
        'username': username,
        if (nickname != null) 'nickname': nickname,
      })) as Map<String, dynamic>;

  static Future<void> removeContact(String contactId) =>
      delete('/api/contacts/$contactId');

  static Future<List<dynamic>> searchUsers(String q) async =>
      (await get('/api/contacts/search?q=${Uri.encodeComponent(q)}')) as List<dynamic>;

  static Future<void> savePushToken(String token) =>
      post('/api/contacts/push-token', {'token': token, 'platform': 'android'});

  // --- Chats ---
  static Future<List<dynamic>> getChats() async =>
      (await get('/api/chats')) as List<dynamic>;

  static Future<Map<String, dynamic>> openDirectChat(String targetUserId) async =>
      (await post('/api/chats/direct', {'targetUserId': targetUserId})) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds,
      {String? description}) async =>
      (await post('/api/chats/group', {
        'name': name, 'memberIds': memberIds,
        if (description != null) 'description': description,
      })) as Map<String, dynamic>;

  static Future<List<dynamic>> getMessages(String chatId, {String? before}) async {
    final q = before != null ? '?before=${Uri.encodeComponent(before)}' : '';
    return (await get('/api/chats/$chatId/messages$q')) as List<dynamic>;
  }

  static Future<List<dynamic>> getMembers(String chatId) async =>
      (await get('/api/chats/$chatId/members')) as List<dynamic>;

  static Future<Map<String, dynamic>> reactToMessage(
      String chatId, String messageId, String emoji) async =>
      (await post('/api/chats/$chatId/messages/$messageId/react', {'emoji': emoji}))
          as Map<String, dynamic>;

  // --- Media ---
  static Future<Map<String, dynamic>> uploadMedia(
      String base64Data, String mime) async =>
      (await post('/api/media/upload', {'data': base64Data, 'mime': mime}))
          as Map<String, dynamic>;

  // --- Channels ---
  static Future<List<dynamic>> exploreChannels({String? q}) async {
    final qs = q != null ? '?q=${Uri.encodeComponent(q)}' : '';
    return (await get('/api/channels/explore$qs')) as List<dynamic>;
  }

  static Future<List<dynamic>> myChannels() async =>
      (await get('/api/channels/my')) as List<dynamic>;

  static Future<Map<String, dynamic>> getChannel(String username) async =>
      (await get('/api/channels/$username')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> subscribeChannel(String channelId) async =>
      (await post('/api/channels/$channelId/subscribe', {})) as Map<String, dynamic>;

  static Future<List<dynamic>> getChannelPosts(String channelId) async =>
      (await get('/api/channels/$channelId/posts')) as List<dynamic>;

  static Future<Map<String, dynamic>> createChannel(
      String username, String name, String? description) async =>
      (await post('/api/channels', {
        'username': username, 'name': name,
        if (description != null) 'description': description,
      })) as Map<String, dynamic>;

  // --- AI ---
  static Future<String> askAi(String chatId, String message) async {
    final data = await post('/api/ai/chat/$chatId',
        {'message': message, 'includeHistory': true});
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
