import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Helper class for picking and cropping images with consistent UI
class ImageCropHelper {
  /// Pick and crop an image for profile pictures (square/circle crop)
  /// Returns the cropped image file or null if cancelled
  static Future<File?> pickAndCropProfileImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      // Crop the image with square aspect ratio for profile pics
      final croppedFile = await _cropImage(
        context,
        pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        cropStyle: CropStyle.circle,
        title: 'Crop Profile Picture',
      );

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking/cropping profile image: $e');
      return null;
    }
  }

  /// Pick and crop an image for group chat photos (square crop)
  /// Returns the cropped image file or null if cancelled
  static Future<File?> pickAndCropGroupImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      // Crop the image with square aspect ratio for group photos
      final croppedFile = await _cropImage(
        context,
        pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        cropStyle: CropStyle.rectangle,
        title: 'Crop Group Photo',
      );

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking/cropping group image: $e');
      return null;
    }
  }

  /// Pick and crop an image for chat backgrounds (9:16 vertical/portrait)
  /// Returns the cropped image file or null if cancelled
  static Future<File?> pickAndCropBackgroundImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Crop the image with 9:16 aspect ratio for vertical backgrounds
      final croppedFile = await _cropImage(
        context,
        pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
        cropStyle: CropStyle.rectangle,
        title: 'Crop Background Image',
      );

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking/cropping background image: $e');
      return null;
    }
  }

  /// Internal method to crop an image with the image_cropper package
  static Future<File?> _cropImage(
    BuildContext context,
    String imagePath, {
    required CropAspectRatio aspectRatio,
    required CropStyle cropStyle,
    required String title,
  }) async {
    try {
      // Extract theme data BEFORE async operation to avoid accessing deactivated widget
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final surface = colorScheme.surface;
      final onSurface = colorScheme.onSurface;
      final background = colorScheme.background;
      final primary = colorScheme.primary;
      final primaryWithOpacity = primary.withOpacity(0.3);

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: aspectRatio,
        compressQuality: 90,
        cropStyle: cropStyle,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: surface,
            toolbarWidgetColor: onSurface,
            backgroundColor: background,
            activeControlsWidgetColor: primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
            cropFrameColor: primary,
            cropGridColor: primaryWithOpacity,
          ),
          IOSUiSettings(
            title: title,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: false,
            aspectRatioPickerButtonHidden: true,
          ),
          // WebUiSettings removed - context may be deactivated during async operation
          // Web will use default cropper UI
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }

      return null;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  /// Pick and crop an image with custom aspect ratio
  /// Returns the cropped image file or null if cancelled
  static Future<File?> pickAndCropCustom(
    BuildContext context, {
    double ratioX = 1,
    double ratioY = 1,
    CropStyle cropStyle = CropStyle.rectangle,
    String title = 'Crop Image',
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 90,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      final croppedFile = await _cropImage(
        context,
        pickedFile.path,
        aspectRatio: CropAspectRatio(ratioX: ratioX, ratioY: ratioY),
        cropStyle: cropStyle,
        title: title,
      );

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking/cropping custom image: $e');
      return null;
    }
  }
}
