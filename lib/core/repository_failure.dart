/// A repository call was refused because the fake's failure toggle is on.
class RepositoryFailure implements Exception {
  const RepositoryFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'RepositoryFailure: $message';
}
