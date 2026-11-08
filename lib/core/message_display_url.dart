import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Coerce message metadata (Map or JSON string) without dropping photos.
Map<String, dynamic>? asMessageMetadataMap(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Display URL for image media. Prefer media_url, then metadata.photos[0].
/// Does not infer message type.
String? resolveMessageDisplayMediaUrl(Map<String, dynamic> data) {
  final direct =
      _nonEmptyUrl(data['media_url']) ?? _nonEmptyUrl(data['mediaUrl']);
  if (direct != null) return direct;

  final metadata = asMessageMetadataMap(data['metadata']);
  if (metadata != null) {
    final photos = metadata['photos'];
    final fromPhotos = _firstPhotoUrl(photos);
    if (fromPhotos != null) {
      if (kDebugMode) {
        debugPrint('photos resolved from metadata');
      }
      return fromPhotos;
    }
    for (final key in const [
      'photo',
      'image',
      'images',
      'image_url',
      'imageUrl',
      'photo_url',
      'photoUrl',
      'thumbnail',
      'thumbnail_url',
      'thumbnailUrl',
      'src',
      'uri',
      'url',
    ]) {
      final fromEquivalent = _firstPhotoUrl(metadata[key]) ??
          _urlFromPhotoEntry(metadata[key]);
      if (fromEquivalent != null) {
        if (kDebugMode) {
          debugPrint('photos resolved from metadata');
        }
        return fromEquivalent;
      }
    }
  }

  return _firstPhotoUrl(data['photos']);
}

String? _nonEmptyUrl(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

String? _firstPhotoUrl(Object? photos) {
  if (photos == null) return null;
  if (photos is String) {
    final direct = _nonEmptyUrl(photos);
    if (direct != null && !direct.startsWith('{') && !direct.startsWith('[')) {
      return direct;
    }
    try {
      final decoded = jsonDecode(photos);
      return _firstPhotoUrl(decoded);
    } catch (_) {
      return _nonEmptyUrl(photos);
    }
  }
  if (photos is List) {
    if (photos.isEmpty) return null;
    return _urlFromPhotoEntry(photos.first);
  }
  if (photos is Map) {
    return _urlFromPhotoEntry(photos);
  }
  return _urlFromPhotoEntry(photos);
}

String? _urlFromPhotoEntry(Object? entry) {
  final asString = _nonEmptyUrl(entry);
  if (asString != null) return asString;
  if (entry is! Map) return null;
  for (final key in const [
    'uri',
    'url',
    'src',
    'href',
    'link',
    'path',
    'media_url',
    'mediaUrl',
    'image_url',
    'imageUrl',
    'photo_url',
    'photoUrl',
    'publicUrl',
    'public_url',
    'signedUrl',
    'signed_url',
    'downloadUrl',
    'download_url',
    'thumbnail',
    'thumbnailUrl',
    'thumbnail_url',
    'file',
    'filename',
  ]) {
    final value = _nonEmptyUrl(entry[key]);
    if (value != null) return value;
  }
  return null;
}
