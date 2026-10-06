/// Data models for the MovieBox wrapper API.
/// Parsing is deliberately defensive: field names vary between endpoints.

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;

String _pickImage(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) return _s(v['url'] ?? v['src'] ?? v['image']);
  return '';
}

class TitleItem {
  final String id;
  final String title;
  final String poster;
  final String backdrop;
  final String description;
  final String year;
  final String genre;
  final bool isSeries;
  final double rating;

  const TitleItem({
    required this.id,
    required this.title,
    this.poster = '',
    this.backdrop = '',
    this.description = '',
    this.year = '',
    this.genre = '',
    this.isSeries = false,
    this.rating = 0,
  });

  /// Used for My List storage (our own stable format).
  Map<String, dynamic> toStore() => {
        'id': id,
        'title': title,
        'poster': poster,
        'backdrop': backdrop,
        'description': description,
        'year': year,
        'genre': genre,
        'isSeries': isSeries,
        'rating': rating,
      };

  factory TitleItem.fromStore(Map<String, dynamic> j) => TitleItem(
        id: _s(j['id']),
        title: _s(j['title']),
        poster: _s(j['poster']),
        backdrop: _s(j['backdrop']),
        description: _s(j['description']),
        year: _s(j['year']),
        genre: _s(j['genre']),
        isSeries: j['isSeries'] == true,
        rating: (j['rating'] is num) ? (j['rating'] as num).toDouble() : 0,
      );

  /// Fill empty fields from [other] (info endpoint often has more detail).
  TitleItem merge(TitleItem other) => TitleItem(
        id: id,
        title: other.title.isNotEmpty ? other.title : title,
        poster: other.poster.isNotEmpty ? other.poster : poster,
        backdrop: other.backdrop.isNotEmpty ? other.backdrop : backdrop,
        description: other.description.isNotEmpty ? other.description : description,
        year: other.year.isNotEmpty ? other.year : year,
        genre: other.genre.isNotEmpty ? other.genre : genre,
        isSeries: isSeries || other.isSeries,
        rating: other.rating > 0 ? other.rating : rating,
      );

  factory TitleItem.fromJson(Map<String, dynamic> j) {
    final type = _s(j['type'] ?? j['subjectType']).toLowerCase();
    final genre = j['genre'];
    return TitleItem(
      id: _s(j['id'] ?? j['subjectId']),
      title: _s(j['title'] ?? j['name']),
      poster: _pickImage(j['poster'] ?? j['cover'] ?? j['image']),
      backdrop: _pickImage(j['backdrop'] ?? j['banner'] ?? j['cover']),
      description: _s(j['description'] ?? j['overview']),
      year: _s(j['year'] ?? j['releaseDate']).split('-').first,
      genre: genre is List ? genre.join(', ') : _s(genre),
      isSeries: type.contains('series') || type == 'tv' || type == '2',
      rating: double.tryParse(_s(j['rating'] ?? j['imdbRatingValue'])) ?? 0,
    );
  }
}

class Episode {
  final int season;
  final int number;
  final String title;
  final String thumbnail;

  const Episode({
    required this.season,
    required this.number,
    this.title = '',
    this.thumbnail = '',
  });

  factory Episode.fromJson(Map<String, dynamic> j, {int season = 1}) {
    return Episode(
      season: _i(j['season'] ?? j['se'] ?? season),
      number: _i(j['episode'] ?? j['ep'] ?? j['number']),
      title: _s(j['title'] ?? j['name']),
      thumbnail: _pickImage(j['thumbnail'] ?? j['cover'] ?? j['image']),
    );
  }
}

class Subtitle {
  final String language;
  final String url;

  const Subtitle({required this.language, required this.url});

  factory Subtitle.fromJson(Map<String, dynamic> j) => Subtitle(
        language: _s(j['language'] ?? j['lang'] ?? j['name']),
        url: _s(j['url'] ?? j['src']),
      );
}

class StreamInfo {
  final String id;
  final String url; // DASH .mpd
  final String signCookie;
  final String quality;

  const StreamInfo({
    required this.id,
    required this.url,
    this.signCookie = '',
    this.quality = '',
  });

  factory StreamInfo.fromJson(Map<String, dynamic> j) => StreamInfo(
        id: _s(j['id'] ?? j['streamId']),
        url: _s(j['url']),
        signCookie: _s(j['signCookie']),
        quality: _s(j['quality'] ?? j['resolution']),
      );

  /// Headers to give the player for manifest + segment requests.
  Map<String, String> get headers =>
      signCookie.isEmpty ? {} : {'Cookie': signCookie};
}

class DubOption {
  final String id;
  final String language;

  const DubOption({required this.id, required this.language});

  factory DubOption.fromJson(Map<String, dynamic> j) => DubOption(
        id: _s(j['id'] ?? j['subjectId']),
        language: _s(j['language'] ?? j['lang'] ?? j['name']),
      );
}

/// One "Continue Watching" entry (latest unfinished item per title).
class WatchEntry {
  final TitleItem item;
  final String contentId; // active id (dub) used for playback
  final int season; // 0 for movies
  final int episode; // 0 for movies
  final int posMs;
  final int durMs;
  final int ts;
  final bool upNext; // queued next episode, nothing watched yet

  const WatchEntry({
    required this.item,
    required this.contentId,
    required this.season,
    required this.episode,
    required this.posMs,
    required this.durMs,
    required this.ts,
    this.upNext = false,
  });

  double get fraction =>
      upNext || durMs <= 0 ? 0 : (posMs / durMs).clamp(0.0, 1.0).toDouble();

  Duration get remaining => Duration(milliseconds: (durMs - posMs).clamp(0, durMs));
}
