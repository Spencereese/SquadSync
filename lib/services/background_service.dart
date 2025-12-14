import 'dart:io';
import 'package:flutter/foundation.dart';
import 'auth_service_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for managing per-chat custom backgrounds
///
/// Features:
/// - Set background type (color, gradient, image, preset)
/// - Upload custom background images to Supabase Storage
/// - Stream current background settings from Supabase
/// - Predefined presets for quick selection
class BackgroundService {
  final AuthServiceSupabase _auth;

  BackgroundService({
    AuthServiceSupabase? auth,
  }) : _auth = auth ?? AuthServiceSupabase();

  /// Predefined background presets
  /// Keys are preset IDs, values are asset paths or URLs
  static const Map<String, String> presets = {
    // NEON VOID themed presets
    'matrix_rain': 'assets/images/backgrounds/matrix_rain.gif',
    'warzone_green': 'assets/images/backgrounds/warzone_green.jpg',
    'cyberpunk_city': 'assets/images/backgrounds/cyberpunk_city.jpg',
    'neon_grid': 'assets/images/backgrounds/neon_grid.jpg',
    'space_nebula': 'assets/images/backgrounds/space_nebula.jpg',
    'digital_void': 'assets/images/backgrounds/digital_void.jpg',
    'glitch_pattern': 'assets/images/backgrounds/glitch_pattern.jpg',
    'particle_flow': 'assets/images/backgrounds/particle_flow.gif',

    // Solid color presets (hex values)
    'dark_void': '#0B0E14',
    'deep_purple': '#1A0B2E',
    'midnight_blue': '#0D1B2A',
    'forest_night': '#0F1E1A',

    // Gradient presets (encoded as gradient string)
    'neon_horizon': 'gradient:linear:0xFF00F5FF,0xFFFF00FF',
    'sunset_void': 'gradient:linear:0xFFFF6B35,0xFF4A1C8C',
    'emerald_dream': 'gradient:linear:0xFF00F5A0,0xFF00D9F5',
    'fire_storm': 'gradient:radial:0xFFFF4500,0xFF8B0000',
  };

  /// Apply a background to a chat group
  ///
  /// [chatGroupId] - The chat group/squad ID
  /// [type] - Background type: 'color', 'gradient', 'image', 'preset', 'none'
  /// [value] - Background value (color hex, image URL, gradient string, preset ID)
  ///
  /// Examples:
  /// ```dart
  /// // Solid color
  /// await applyBackground('squad_123', type: 'color', value: '#0B0E14');
  ///
  /// // Image URL
  /// await applyBackground('squad_123', type: 'image', value: 'https://...');
  ///
  /// // Preset
  /// await applyBackground('squad_123', type: 'preset', value: 'matrix_rain');
  ///
  /// // None (remove background)
  /// await applyBackground('squad_123', type: 'none', value: '');
  /// ```
  Future<void> applyBackground(
    String chatGroupId, {
    required String type,
    required String value,
  }) async {
    try {
      final currentUserId = _auth.currentUserId;
      if (currentUserId == null) {
        throw Exception('User must be authenticated to apply backgrounds');
      }

      // Validate type
      final validTypes = ['color', 'gradient', 'image', 'preset', 'none'];
      if (!validTypes.contains(type)) {
        throw ArgumentError(
          'Invalid background type: $type. Must be one of: ${validTypes.join(', ')}',
        );
      }

      // Validate preset if type is preset
      if (type == 'preset' && !presets.containsKey(value)) {
        throw ArgumentError(
          'Invalid preset: $value. Available presets: ${presets.keys.join(', ')}',
        );
      }

      // Background columns exist in production schema (confirmed Dec 12, 2025)
      // Columns: background_type, background_value, background_updated_at, background_updated_by
      await SupabaseService.client.from('chat_groups').update({
        'background_type': type,
        'background_value': value,
        'background_updated_at': DateTime.now().toIso8601String(),
        'background_updated_by': currentUserId,
      }).eq('id', chatGroupId);

      debugPrint(
        'Background applied: chatGroupId=$chatGroupId, type=$type, value=$value',
      );
    } catch (e) {
      debugPrint('Error applying background: $e');
      rethrow;
    }
  }

  /// Upload a custom background image to Firebase Storage
  ///
  /// [chatGroupId] - The chat group/squad ID
  /// [filePath] - Local file path to the image
  ///
  /// Returns the download URL of the uploaded image
  ///
  /// Automatically calls [applyBackground] with the uploaded image URL
  Future<String> uploadCustomBackground(
    String chatGroupId,
    String filePath,
  ) async {
    try {
      final currentUserId = _auth.currentUserId;
      if (currentUserId == null) {
        throw Exception('User must be authenticated to upload backgrounds');
      }

      // Validate file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      // Check file size (max 5MB)
      final fileSize = await file.length();
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        throw Exception(
          'File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB. Max size: 5MB',
        );
      }

      debugPrint(
          'Uploading background: $filePath (${(fileSize / 1024).toStringAsFixed(2)}KB)');

      // Upload to Supabase Storage (RLS requires {user_uid}/{filename})
      final user = AuthServiceSupabase().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'bg_${chatGroupId}_$timestamp.jpg';
      final storagePath = '${user.id}/$fileName';

      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Upload to Supabase Storage
      final supabase = SupabaseService.client;
      await supabase.storage.from('chat-backgrounds').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(filePath),
              upsert: false,
            ),
          );

      // Get public URL
      final downloadUrl =
          supabase.storage.from('chat-backgrounds').getPublicUrl(storagePath);

      debugPrint('Upload complete: $downloadUrl');

      // Apply the uploaded image as background
      await applyBackground(
        chatGroupId,
        type: 'image',
        value: downloadUrl,
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading background: $e');
      rethrow;
    }
  }

  /// Get the current background settings for a chat group
  ///
  /// Returns a stream of background data that updates in real-time
  ///
  /// Stream emits a Map with keys:
  /// - `type`: Background type ('color', 'gradient', 'image', 'preset', 'none')
  /// - `value`: Background value (color, URL, preset ID, etc.)
  /// - `updatedAt`: Timestamp of last update
  /// - `updatedBy`: UID of user who set the background
  ///
  /// Example:
  /// ```dart
  /// backgroundService.getCurrentBackground('squad_123').listen((data) {
  ///   print('Background type: ${data['type']}');
  ///   print('Background value: ${data['value']}');
  /// });
  /// ```
  Stream<Map<String, dynamic>> getCurrentBackground(String chatGroupId) {
    // Background columns enabled in production (Dec 12, 2025)
    return SupabaseService.client
        .from('chat_groups')
        .stream(primaryKey: ['id'])
        .eq('id', chatGroupId)
        .map((list) {
          if (list.isEmpty) {
            return {
              'type': 'none',
              'value': '',
              'updatedAt': null,
              'updatedBy': null,
            };
          }

          final data = list.first;

          return {
            'type': data['background_type'] ?? 'none',
            'value': data['background_value'] ?? '',
            'updatedAt': data['background_updated_at'],
            'updatedBy': data['background_updated_by'],
          };
        });
  }

  /// Get background data as a Future (one-time read)
  ///
  /// Useful when you don't need real-time updates
  Future<Map<String, dynamic>> getBackgroundOnce(String chatGroupId) async {
    // Background columns enabled in production (Dec 12, 2025)
    final response = await SupabaseService.client
        .from('chat_groups')
        .select(
            'background_type, background_value, background_updated_at, background_updated_by')
        .eq('id', chatGroupId)
        .maybeSingle();

    if (response == null) {
      return {
        'type': 'none',
        'value': '',
        'updatedAt': null,
        'updatedBy': null,
      };
    }

    return {
      'type': response['background_type'] ?? 'none',
      'value': response['background_value'] ?? '',
      'updatedAt': response['background_updated_at'],
      'updatedBy': response['background_updated_by'],
    };
  }

  /// Remove/clear the background for a chat group
  Future<void> removeBackground(String chatGroupId) async {
    await applyBackground(chatGroupId, type: 'none', value: '');
  }

  /// Delete a custom uploaded background from Storage
  ///
  /// This removes the file from Storage
  /// Call [removeBackground] separately to clear it from the chat
  Future<void> deleteCustomBackground(
      String chatGroupId, String imageUrl) async {
    try {
      // Extract storage path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket and file path
      if (pathSegments.contains('chat-backgrounds')) {
        final bucketIndex = pathSegments.indexOf('chat-backgrounds');
        final filePath = pathSegments.skip(bucketIndex + 1).join('/');

        // Delete from Supabase Storage
        final supabase = SupabaseService.client;
        await supabase.storage.from('chat-backgrounds').remove([filePath]);

        debugPrint('Deleted custom background: $imageUrl');
      } else {
        debugPrint('Could not parse storage path from URL: $imageUrl');
      }
    } catch (e) {
      debugPrint('Error deleting background: $e');
      rethrow;
    }
  }

  /// Get all custom backgrounds uploaded for a chat group
  ///
  /// Returns a list of download URLs for all uploaded backgrounds
  Future<List<String>> getUploadedBackgrounds(String chatGroupId) async {
    try {
      // List files in Supabase Storage for this chat group
      final supabase = SupabaseService.client;
      final files = await supabase.storage
          .from('chat-backgrounds')
          .list(path: chatGroupId);

      // Get public URLs for all files
      final urls = files.map((file) {
        final path = '$chatGroupId/${file.name}';
        return supabase.storage.from('chat-backgrounds').getPublicUrl(path);
      }).toList();

      debugPrint('Found ${urls.length} uploaded backgrounds for $chatGroupId');
      return urls;
    } catch (e) {
      debugPrint('Error fetching uploaded backgrounds: $e');
      return [];
    }
  }

  /// Apply a preset background by ID
  ///
  /// Convenience method for applying preset backgrounds
  Future<void> applyPreset(String chatGroupId, String presetId) async {
    if (!presets.containsKey(presetId)) {
      throw ArgumentError('Unknown preset: $presetId');
    }

    await applyBackground(
      chatGroupId,
      type: 'preset',
      value: presetId,
    );
  }

  /// Apply a solid color background
  ///
  /// [color] - Hex color string (e.g., '#0B0E14')
  Future<void> applyColorBackground(String chatGroupId, String color) async {
    // Validate hex color format
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
      throw ArgumentError('Invalid hex color format: $color');
    }

    await applyBackground(
      chatGroupId,
      type: 'color',
      value: color,
    );
  }

  /// Apply a gradient background
  ///
  /// [gradientString] - Encoded gradient string
  /// Format: "gradient:type:color1,color2,..."
  /// Example: "gradient:linear:0xFF00F5FF,0xFFFF00FF"
  Future<void> applyGradientBackground(
    String chatGroupId,
    String gradientString,
  ) async {
    // Validate gradient format
    if (!gradientString.startsWith('gradient:')) {
      throw ArgumentError('Invalid gradient format: $gradientString');
    }

    await applyBackground(
      chatGroupId,
      type: 'gradient',
      value: gradientString,
    );
  }

  /// Get the actual background value for a preset
  ///
  /// Returns the asset path or color value for a given preset ID
  static String? getPresetValue(String presetId) {
    return presets[presetId];
  }

  /// Check if a preset is an animated background (GIF)
  static bool isAnimatedPreset(String presetId) {
    final value = presets[presetId];
    if (value == null) return false;
    return value.toLowerCase().endsWith('.gif');
  }

  /// Check if a preset is a gradient
  static bool isGradientPreset(String presetId) {
    final value = presets[presetId];
    if (value == null) return false;
    return value.startsWith('gradient:');
  }

  /// Check if a preset is a solid color
  static bool isColorPreset(String presetId) {
    final value = presets[presetId];
    if (value == null) return false;
    return value.startsWith('#');
  }

  /// Get content type from file extension
  String _getContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }
}

/// Background data model for easier usage
class ChatBackground {
  final String type;
  final String value;
  final DateTime? updatedAt;
  final String? updatedBy;

  ChatBackground({
    required this.type,
    required this.value,
    this.updatedAt,
    this.updatedBy,
  });

  factory ChatBackground.fromMap(Map<String, dynamic> map) {
    return ChatBackground(
      type: map['type'] ?? 'none',
      value: map['value'] ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      updatedBy: map['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  bool get isNone => type == 'none';
  bool get isColor => type == 'color';
  bool get isGradient => type == 'gradient';
  bool get isImage => type == 'image';
  bool get isPreset => type == 'preset';

  @override
  String toString() {
    return 'ChatBackground(type: $type, value: $value)';
  }
}
