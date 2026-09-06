import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/utils/result.dart';

void main() {
  group('Result', () {
    test('ok() carries the given data and no error', () {
      final result = Result<int>.ok(42);

      expect(result.success, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, 42);
      expect(result.error, isNull);
    });

    test('ok() with no argument still succeeds, with null data', () {
      final result = Result<int>.ok();

      expect(result.success, isTrue);
      expect(result.data, isNull);
    });

    test('fail() carries the given error and no data', () {
      final result = Result<int>.fail('boom');

      expect(result.success, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.data, isNull);
      expect(result.error, 'boom');
    });

    test('toString reports success with data', () {
      expect(Result<int>.ok(1).toString(), contains('1'));
    });

    test('toString reports failure with the error message', () {
      expect(Result<int>.fail('nope').toString(), contains('nope'));
    });
  });

  group('VoidResult', () {
    test('is a Result<void> and supports the same factories', () {
      final ok = VoidResult.ok();
      final fail = VoidResult.fail('denied');

      expect(ok.success, isTrue);
      expect(fail.success, isFalse);
      expect(fail.error, 'denied');
    });
  });
}
