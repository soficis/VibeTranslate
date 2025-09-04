/// Clean Code Either type for explicit error handling
/// Following functional programming principles for type safety
library;

import 'failure.dart';

/// Represents a value that can be either a success (Right) or failure (Left)
/// Following the Either convention where Right represents success
sealed class Either<L, R> {
  const Either();

  /// Returns true if this is a Left (failure) value
  bool get isLeft => this is Left<L, R>;

  /// Returns true if this is a Right (success) value
  bool get isRight => this is Right<L, R>;

  /// Get the Left value or throw an exception if this is Right
  L get left => fold(
        (left) => left,
        (right) => throw Exception('Called left on Right value'),
      );

  /// Get the Right value or throw an exception if this is Left
  R get right => fold(
        (left) => throw Exception('Called right on Left value'),
        (right) => right,
      );

  /// Pattern matching for Either values
  T fold<T>(
    T Function(L left) onLeft,
    T Function(R right) onRight,
  );

  /// Transform the Right value if this is Right, otherwise return this Left
  Either<L, T> map<T>(T Function(R right) transform) {
    return fold(
      Left<L, T>.new,
      (right) => Right<L, T>(transform(right)),
    );
  }

  /// Transform the Right value to another Either if this is Right
  Either<L, T> flatMap<T>(Either<L, T> Function(R right) transform) {
    return fold(
      Left<L, T>.new,
      transform,
    );
  }

  /// Transform the Left value if this is Left, otherwise return this Right
  Either<T, R> mapLeft<T>(T Function(L left) transform) {
    return fold(
      (left) => Left<T, R>(transform(left)),
      Right<T, R>.new,
    );
  }

  /// Get the Right value or return the provided default
  R getOrElse(R Function() defaultValue) {
    return fold(
      (left) => defaultValue(),
      (right) => right,
    );
  }

  /// Get the Right value or return null if this is Left
  R? getOrNull() {
    return fold(
      (left) => null,
      (right) => right,
    );
  }
}

/// Represents a failure (Left) value
class Left<L, R> extends Either<L, R> {
  final L value;

  const Left(this.value);

  @override
  T fold<T>(
    T Function(L left) onLeft,
    T Function(R right) onRight,
  ) {
    return onLeft(value);
  }

  @override
  bool operator ==(Object other) => other is Left<L, R> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// Represents a success (Right) value
class Right<L, R> extends Either<L, R> {
  final R value;

  const Right(this.value);

  @override
  T fold<T>(
    T Function(L left) onLeft,
    T Function(R right) onRight,
  ) {
    return onRight(value);
  }

  @override
  bool operator ==(Object other) =>
      other is Right<L, R> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// Type alias for Result type commonly used in the app
typedef Result<T> = Either<Failure, T>;
