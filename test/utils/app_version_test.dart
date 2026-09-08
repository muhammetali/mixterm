import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/utils/constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// These guard one class of bug, not one bug.
///
/// `AppConstants.appVersion` was a literal `'1.0.0'` and stayed that way
/// through 1.1.0, so the About section reported a version that had not
/// shipped in two releases. `snap/snapcraft.yaml` had the identical defect
/// and shipped a 1.1.0 snap labelled 1.0.0. Neither failed anything: a stale
/// version string is still a well-formed version string, which is precisely
/// why it needs a test rather than review.
///
/// The rule these encode: `pubspec.yaml` is the only file that may state the
/// version. Everything else derives it.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('the version has a single source', () {
    test('pubspec declares one well-formed version', () {
      final declarations = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();

      expect(declarations, hasLength(1),
          reason: 'pubspec.yaml must declare exactly one version');
      expect(declarations.single, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')),
          reason: 'expected semver plus a build number, e.g. 1.1.0+2');
    });

    test('no Dart source restates the version', () {
      // Deliberately zero rather than a ratchet: unlike a raw colour, there
      // is no legitimate reason for application code to name its own
      // version, so anything above zero is the bug returning.
      final literal = RegExp(
          '''(?:appVersion|version)\\s*=\\s*['"]v?\\d+\\.\\d+\\.\\d+''');
      final offenders = <String>[];

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (literal.hasMatch(file.readAsStringSync())) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'read the version from the package, do not restate it: '
              '$offenders');
    });

    test('the snap manifest adopts the version rather than stating it', () {
      final snapcraft = File('snap/snapcraft.yaml');
      if (!snapcraft.existsSync()) return;

      final source = snapcraft.readAsStringSync();
      expect(source, contains('adopt-info:'),
          reason: 'snapcraft must take its version from pubspec');
      expect(RegExp(r'''^version:\s*['"]?\d''', multiLine: true)
          .hasMatch(source), isFalse,
          reason: 'a literal version here shipped 1.1.0 labelled 1.0.0');
    });
  });

  group('AppConstants.loadVersion', () {
    setUp(() => AppConstants.appVersion = AppConstants.unknownVersion);

    test('reports the platform version with its build number', () async {
      PackageInfo.setMockInitialValues(
        appName: 'MixTerm',
        packageName: 'com.mixterm.app',
        version: '2.3.4',
        buildNumber: '7',
        buildSignature: '',
      );

      await AppConstants.loadVersion();

      expect(AppConstants.appVersion, '2.3.4 (7)');
    });

    test('omits the build number when the platform has none', () async {
      PackageInfo.setMockInitialValues(
        appName: 'MixTerm',
        packageName: 'com.mixterm.app',
        version: '2.3.4',
        buildNumber: '',
        buildSignature: '',
      );

      await AppConstants.loadVersion();

      expect(AppConstants.appVersion, '2.3.4');
    });

    test('keeps "unknown" rather than inventing a version', () async {
      // An empty version is what an unpackaged or misconfigured build
      // reports. Showing "0.0.0" or a stale default there is worse than
      // admitting the version is not known.
      PackageInfo.setMockInitialValues(
        appName: 'MixTerm',
        packageName: 'com.mixterm.app',
        version: '',
        buildNumber: '',
        buildSignature: '',
      );

      await AppConstants.loadVersion();

      expect(AppConstants.appVersion, AppConstants.unknownVersion);
    });
  });
}
