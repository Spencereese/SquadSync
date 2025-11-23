import 'package:squad_sync/domain/repositories/chat_repository.dart';

class UploadMedia {
  final ChatRepository _repository;

  UploadMedia(this._repository);

  Future<String> call(String filePath, String mediaType) =>
      _repository.uploadMedia(filePath, mediaType);
}