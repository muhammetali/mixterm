/// A typed success/failure outcome carrying either a value or a
/// human-readable error message.
///
/// Use this instead of returning `null`/`false`/an empty collection on
/// failure — those shapes are indistinguishable from a legitimate empty
/// result and discard the actual reason an operation failed, which is
/// exactly the information a user-facing error message needs.
class Result<T> {
  final bool success;
  final T? data;
  final String? error;

  const Result._({required this.success, this.data, this.error});

  factory Result.ok([T? data]) => Result<T>._(success: true, data: data);

  factory Result.fail(String error) =>
      Result<T>._(success: false, error: error);

  bool get isFailure => !success;

  @override
  String toString() => success ? 'Result.ok($data)' : 'Result.fail($error)';
}

/// A [Result] for operations with no meaningful success payload — the
/// operation either completed or it didn't.
typedef VoidResult = Result<void>;
