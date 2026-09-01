/// Display URL for image media. Prefer media_url, then metadata.photos[0].
/// Does not infer message type.
String? resolveMessageDisplayMediaUrl(Map<String, dynamic> data) {
  final direct =
      _nonEmptyUrl(data['media_url']) ?? _nonEmptyUrl(data['mediaUrl']);
  if (direct != null) return direct;

  final metadata = data['metadata'];
  if (metadata is Map) {
    final fromPhotos = _firstPhotoUrl(metadata['photos']);
    if (fromPhotos != null) return fromPhotos;
    final equivalent = metadata['photo'] ??
        metadata['image'] ??
        metadata['image_url'] ??
        metadata['imageUrl'];
    final fromEquivalent = _urlFromPhotoEntry(equivalent);
    if (fromEquivalent != null) return fromEquivalent;
  }

  return _firstPhotoUrl(data['photos']);
}

String? _nonEmptyUrl(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

String? _firstPhotoUrl(Object? photos) {
  if (photos is! List || photos.isEmpty) return null;
  return _urlFromPhotoEntry(photos.first);
}

String? _urlFromPhotoEntry(Object? entry) {
  final asString = _nonEmptyUrl(entry);
  if (asString != null) return asString;
  if (entry is! Map) return null;
  for (final key in const ['uri', 'url', 'path', 'media_url', 'mediaUrl']) {
    final value = _nonEmptyUrl(entry[key]);
    if (value != null) return value;
  }
  return null;
}
