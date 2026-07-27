sealed class PatResult {
  const PatResult();

  static const awarded = PatResultAwarded._();
  static const capped = PatResultCapped._();
}

final class PatResultAwarded extends PatResult {
  const PatResultAwarded._();
}

final class PatResultCapped extends PatResult {
  const PatResultCapped._();
}
