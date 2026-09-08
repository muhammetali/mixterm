import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Four releases shipped Linux packages that installed and then did not run.
/// Each failure was recoverable in minutes; what cost the time was that
/// nothing said anything was wrong until somebody typed the command on their
/// own machine.
///
/// The release workflow now starts both packages before publishing them, and
/// that is the check that actually catches this class. But those steps only
/// run on a tag, so a change that breaks them is invisible until a release is
/// already half-published. These assert the same properties statically, in a
/// second: they run on `flutter test`, on every branch, before anything is
/// tagged.
///
/// Each one exists because of a specific release:
///
///   1.1.4  a core22 snap built against a 24.04 host — glibc 2.38 not found
///   1.1.5  the same snap, now missing libEGL, which no ldd check can see
///   1.1.7  the same again, plus a .deb that never declared libEGL either
///   1.1.8  finally started before publishing
void main() {
  final workflow = File('.github/workflows/release.yml').readAsStringSync();
  final snapcraft = File('snap/snapcraft.yaml').readAsStringSync();
  final debScript = File('scripts/build_deb.sh').readAsStringSync();

  /// Drops comment lines. Without this an assertion that a flag is *absent*
  /// is satisfied — or defeated — by a comment explaining why it is absent,
  /// which is exactly what happened the first time these ran.
  String withoutComments(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');

  /// The body of one job, so an assertion about the snap job cannot be
  /// satisfied by something in the deb job.
  String job(String name) {
    final start = workflow.indexOf('\n  $name:');
    expect(start, isNot(-1), reason: 'no job named $name');

    final next = RegExp(r'\n  [a-z][a-z0-9-]*:\n').firstMatch(
      workflow.substring(start + 1),
    );
    return next == null
        ? workflow.substring(start)
        : workflow.substring(start, start + 1 + next.start);
  }

  group('every package is started before it is published', () {
    test('the snap is launched in CI', () {
      final snapJob = job('build-snap');
      expect(snapJob, contains('xvfb-run'),
          reason: 'building a snap says nothing about whether it runs — '
              '1.1.5 and 1.1.7 both installed from the store and aborted');
      expect(snapJob, contains('core dumped'),
          reason: 'the launch output has to be inspected, not just produced');
    });

    test('the .deb is installed and launched in CI', () {
      final debJob = job('build-linux-deb');
      expect(debJob, contains('apt-get install -y "./\$deb"'),
          reason: 'the package must be installed, so apt resolves what it '
              'declares');
      expect(debJob, contains('xvfb-run'),
          reason: 'and then run: dpkg-shlibdeps cannot see a dlopen, so the '
              'declaration being present is not the same as it being enough');
    });
  });

  group('the snap cannot inherit the build host', () {
    test('it is not built in destructive mode', () {
      // `--destructive-mode` builds against the runner's apt. That is how a
      // core22 snap came to hold 24.04 libraries: the base and the staged
      // packages came from different places. A container makes them the same
      // thing, so the base is no longer coupled to whatever image GitHub
      // happens to run.
      expect(withoutComments(job('build-snap')),
          isNot(contains('--destructive-mode')));
      expect(job('build-snap'), contains('snapcore/action-build'));
    });

    test('it does not stage its own GTK', () {
      // Staging libgtk-3-0 is what pulled host libraries in. GTK comes from
      // the extension's runtime instead.
      expect(withoutComments(snapcraft), isNot(contains('libgtk-3-0')),
          reason: 'GTK belongs to the gnome extension, not to stage-packages');
    });
  });

  group('the graphics stack is provided, not assumed', () {
    test('the snap uses the gnome extension', () {
      // The engine dlopens libEGL.so.1. Listing libraries one at a time moves
      // the failure to the next dlopen, and mesa staged inside a snap fights
      // the host's drivers; the extension wires in the content snaps that
      // carry GL, GTK and themes.
      expect(snapcraft, matches(RegExp(r'extensions:\s*\n\s*-\s*gnome')),
          reason: 'without this the snap starts and dies on libEGL');
    });

    test('the .deb declares the libraries it opens at runtime', () {
      // dpkg-shlibdeps reads what the ELF links against. libepoxy — which is
      // linked, and does appear in the computed list — loads libEGL.so.1 and
      // libGL.so.1 by name at runtime, so they have to be named explicitly.
      // Without them the package installs on a minimal system and fails.
      for (final library in ['libegl1', 'libgl1']) {
        expect(debScript, contains(library),
            reason: '$library is opened with dlopen and will not be '
                'discovered for us');
      }
    });
  });

  group('the packages describe themselves', () {
    test('the .deb computes its dependencies rather than listing them', () {
      expect(debScript, contains('dpkg-shlibdeps'),
          reason: 'the hand-written Depends omitted libc6 entirely, so apt '
              'installed the package on systems that could not run it');
      expect(File('packaging/debian/control.template').readAsStringSync(),
          contains('__DEPENDS__'),
          reason: 'the template must be filled in, not carry a fixed list');
    });

    test('the .deb ships the files Debian requires', () {
      expect(debScript, contains('copyright'));
      expect(debScript, contains('changelog.gz'));
    });

    test('the snap declares its licence', () {
      expect(snapcraft, contains('license: MIT'));
    });
  });
}
