class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class StreakException implements Exception {
  final String message;
  StreakException(this.message);

  @override
  String toString() => message;
}

class PetException implements Exception {
  final String message;
  PetException(this.message);

  @override
  String toString() => message;
}

class MoodException implements Exception {
  final String message;
  MoodException(this.message);

  @override
  String toString() => message;
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}
