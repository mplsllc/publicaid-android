import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/entity.dart';
import '../models/category.dart';
import '../models/api_response.dart';
import '../models/auth.dart';

class ApiService {
  static const String baseUrl = 'https://publicaid.org/api/v1';
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl/$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, _parseErrorMessage(response.body));
  }

  Future<Map<String, dynamic>> _post(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/$path');
    final response = await http.post(
      uri,
      headers: _headers,
      body: body != null ? json.encode(body) : null,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, _parseErrorMessage(response.body));
  }

  String _parseErrorMessage(String body) {
    try {
      final parsed = json.decode(body) as Map<String, dynamic>;
      return parsed['message'] as String? ??
          parsed['error'] as String? ??
          'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }

  // Search entities
  Future<ApiResponse<List<Entity>>> search({
    String? query,
    String? category,
    String? state,
    double? lat,
    double? lng,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();

    final json = await _get('search', queryParams: params);
    final data = (json['data'] as List<dynamic>)
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] != null
        ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : null;
    return ApiResponse(data: data, meta: meta);
  }

  // Nearby entities
  Future<ApiResponse<List<Entity>>> nearby({
    required double lat,
    required double lng,
    double radius = 25,
    String? category,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty) params['category'] = category;

    final json = await _get('nearby', queryParams: params);
    final data = (json['data'] as List<dynamic>)
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] != null
        ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : null;
    return ApiResponse(data: data, meta: meta);
  }

  // Get entity detail
  Future<Entity> getEntity(String id) async {
    final json = await _get('entities/$id');
    return Entity.fromJson(json['data'] as Map<String, dynamic>);
  }

  // Get entity services
  Future<List<EntityService>> getEntityServices(String id) async {
    final json = await _get('entities/$id/services');
    final data = json['data'];
    if (data == null || data is! List) return [];
    return data
        .map((e) => EntityService.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Get entity hours
  Future<List<EntityHours>> getEntityHours(String id) async {
    final json = await _get('entities/$id/hours');
    final data = json['data'];
    if (data == null || data is! List) return [];
    return data
        .map((e) => EntityHours.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Get categories
  Future<List<Category>> getCategories() async {
    final json = await _get('categories');
    return (json['data'] as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Get filter values
  Future<Map<String, dynamic>> getFilters() async {
    final json = await _get('filters');
    return json['data'] as Map<String, dynamic>;
  }

  static const String _userBaseUrl = 'https://publicaid.org/api/user';

  Future<Map<String, dynamic>> _userPost(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_userBaseUrl/$path');
    final response = await http.post(uri, headers: _headers,
        body: body != null ? json.encode(body) : null);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, _parseErrorMessage(response.body));
  }

  Future<Map<String, dynamic>> _userGet(String path) async {
    final uri = Uri.parse('$_userBaseUrl/$path');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, _parseErrorMessage(response.body));
  }

  // Auth: Login
  Future<Map<String, dynamic>> login(String email, String password,
      {String? altcha}) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (altcha != null) body['altcha'] = altcha;
    return _userPost('login', body: body);
  }

  // Auth: Register
  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String passwordConfirm, {
    String? altcha,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'password_confirm': passwordConfirm,
    };
    if (altcha != null) body['altcha'] = altcha;
    return _userPost('register', body: body);
  }

  // Auth: Get current user
  Future<UserData> getMe() async {
    final json = await _userGet('me');
    return UserData.fromJson(json['data'] as Map<String, dynamic>);
  }

  // Bookmarks: Get list
  Future<List<BookmarkItem>> getBookmarks() async {
    final json = await _userGet('bookmarks');
    final data = json['data'];
    if (data == null || data is! List) return [];
    return data
        .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Bookmarks: Toggle
  Future<bool> toggleBookmark(String entityId) async {
    final json = await _userPost('bookmarks/$entityId');
    return (json['data'] as Map<String, dynamic>)['saved'] as bool? ?? false;
  }

  // Blog: Get articles list
  Future<Map<String, dynamic>> getBlogArticles({
    String? topic,
    String? state,
    int page = 1,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
    };
    if (topic != null && topic.isNotEmpty) params['topic'] = topic;
    if (state != null && state.isNotEmpty) params['state'] = state;
    return _get('blog', queryParams: params);
  }

  // Blog: Get single article by slug
  Future<Map<String, dynamic>> getBlogArticle(String slug) async {
    return _get('blog/$slug');
  }

  // ALTCHA: Get challenge
  Future<AltchaChallenge> getAltchaChallenge() async {
    final uri = Uri.parse('https://publicaid.org/api/altcha/challenge');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return AltchaChallenge.fromJson(data);
    }
    throw ApiException(
        response.statusCode, _parseErrorMessage(response.body));
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
