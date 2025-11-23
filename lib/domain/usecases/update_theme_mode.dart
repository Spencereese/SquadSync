import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';

class UpdateThemeMode {
  final SystemRepository _repository;

  UpdateThemeMode(this._repository);

  Future<void> call(ThemeMode themeMode) => _repository.updateThemeMode(themeMode);
}