/// Minimal Ok/Err result type for domain and platform boundaries.
sealed class Result<T, E> {
  const Result();

  bool get isOk;
  bool get isErr;

  Result<U, E> map<U>(U Function(T value) transform);

  Result<T, F> mapError<F>(F Function(E error) transform);

  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform);

  U fold<U>({
    required U Function(E error) onErr,
    required U Function(T value) onOk,
  });

  T getOrElse(T Function(E error) onErr);
}

/// Successful [Result].
final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;

  @override
  bool get isOk => true;

  @override
  bool get isErr => false;

  @override
  Result<U, E> map<U>(U Function(T value) transform) => Ok<U, E>(transform(value));

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) => Ok<T, F>(value);

  @override
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) =>
      transform(value);

  @override
  U fold<U>({
    required U Function(E error) onErr,
    required U Function(T value) onOk,
  }) =>
      onOk(value);

  @override
  T getOrElse(T Function(E error) onErr) => value;
}

/// Failed [Result].
final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;

  @override
  bool get isOk => false;

  @override
  bool get isErr => true;

  @override
  Result<U, E> map<U>(U Function(T value) transform) => Err<U, E>(error);

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) =>
      Err<T, F>(transform(error));

  @override
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) =>
      Err<U, E>(error);

  @override
  U fold<U>({
    required U Function(E error) onErr,
    required U Function(T value) onOk,
  }) =>
      onErr(error);

  @override
  T getOrElse(T Function(E error) onErr) => onErr(error);
}
