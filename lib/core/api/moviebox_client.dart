import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// HTTP client for the PrimeFlix Vercel wrapper API.
class MovieBoxClient {
  static const baseUrl = 'https://primeflix-moviebox.vercel.app';
  static const _timeout = Duration(seconds: 20);

  /// One shared client -> HTTP keep-alive / connection reuse across screens.
  static final MovieBoxClient shared = MovieBoxClient();

  final http.Client _http;
  MovieBoxClient({http.Client? client}) : _http = client ?? http.Client();

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final res = await _http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        throw ApiException(res.statusCode == 404
            ? 'Not found. This title may no longer be available.'
            : res.statusCode == 401 || res.statusCode == 403
                ? 'Access denied. Check your member key in Settings.'
                : 'Server is busy right now (${res.statusCode}). Please retry.');
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Connection timed out. Please try again.');
    } on FormatException {
      throw ApiException('Unexpected response from the server. Please retry.');
    } on SocketException {
      throw ApiException('No internet connection. Check your network and retry.');
    } on HandshakeException {
      throw ApiException('Secure connection failed. Check date/time and network.');
    } on http.ClientException {
      throw ApiException('No internet connection. Check your network and retry.');
    } catch (_) {
      throw ApiException('Something went wrong. Please retry.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic data, [List<String> keys = const []]) {
    dynamic l = data;
    if (data is Map) {
      for (final k in [...keys, 'items', 'results', 'data']) {
        if (data[k] is List) {
          l = data[k];
          break;
        }
      }
    }
    if (l is! List) return [];
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<TitleItem>> search(String q, {int perPage = 12}) async {
    final data = await _get('/search', {'q': q, 'perPage': '$perPage'});
    return _list(data).map(TitleItem.fromJson).toList();
  }

  Future<TitleItem> info(String id) async {
    final data = await _get('/info/$id');
    final m = data is Map && data['data'] is Map ? data['data'] : data;
    return TitleItem.fromJson(Map<String, dynamic>.from(m as Map));
  }

  Future<List<int>> seasons(String id) async {
    final data = await _get('/seasons/$id');
    final list = _list(data, ['seasons']);
    if (list.isNotEmpty) {
      return list
          .map((e) => int.tryParse('${e['season'] ?? e['se'] ?? e['number']}') ?? 0)
          .where((n) => n > 0)
          .toList();
    }
    if (data is Map && data['seasons'] is List) {
      return (data['seasons'] as List)
          .map((e) => int.tryParse('$e') ?? 0)
          .where((n) => n > 0)
          .toList();
    }
    return [];
  }

  Future<List<Episode>> episodes(String id, int season,
      {int perPage = 300}) async {
    final data =
        await _get('/episodes/$id/$season', {'perPage': '$perPage'});
    return _list(data, ['episodes'])
        .map((e) => Episode.fromJson(e, season: season))
        .toList();
  }

  /// Use season 0 / episode 0 for movies.
  Future<List<StreamInfo>> sources(String id, {int season = 0, int episode = 0}) async {
    final data = await _get('/sources/$id/$season/$episode');
    return _list(data, ['streams']).map(StreamInfo.fromJson).toList();
  }

  Future<List<DubOption>> dubs(String id) async {
    final data = await _get('/dub/$id');
    return _list(data, ['dubs']).map(DubOption.fromJson).toList();
  }

  Future<List<Subtitle>> captions(String id, String streamId) async {
    final data = await _get('/captions/ext/$id/$streamId');
    return _list(data, ['captions', 'subtitles']).map(Subtitle.fromJson).toList();
  }
}
