/// A repository call was refused because the fake's failure toggle is on.
class RepositoryFailure implements Exception {
  const RepositoryFailure(this.message);

  final String message;

  @override
  String toString() => 'RepositoryFailure: $message';
}
