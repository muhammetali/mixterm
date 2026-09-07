import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/widgets/sftp_browser.dart';

void main() {
  group('breadcrumbSegments', () {
    test('root is a single entry, not a segment plus a separator', () {
      // Regression test. The original built the bar as "root segment, then a
      // separator before every name", so the root `/` was immediately
      // followed by another `/` and every path opened with `/ / home`.
      // Root is both the segment and the separator that precedes the first
      // name, so exactly one of them belongs at the start.
      expect(breadcrumbSegments('/'), const [BreadcrumbEntry('/', '/')]);
    });

    test('splits an absolute path into cumulative targets', () {
      expect(breadcrumbSegments('/home/mali'), const [
        BreadcrumbEntry('/', '/'),
        BreadcrumbEntry('home', '/home'),
        BreadcrumbEntry('mali', '/home/mali'),
      ]);
    });

    test('every entry after root navigates to its own full path', () {
      final entries = breadcrumbSegments('/var/log/nginx');
      expect(entries.map((e) => e.path), [
        '/',
        '/var',
        '/var/log',
        '/var/log/nginx',
      ]);
    });

    test('a trailing slash does not produce an empty segment', () {
      expect(breadcrumbSegments('/home/mali/'), breadcrumbSegments('/home/mali'));
    });

    test('repeated slashes collapse', () {
      expect(breadcrumbSegments('//home///mali'), const [
        BreadcrumbEntry('/', '/'),
        BreadcrumbEntry('home', '/home'),
        BreadcrumbEntry('mali', '/home/mali'),
      ]);
    });

    test('an empty path still yields root', () {
      expect(breadcrumbSegments(''), const [BreadcrumbEntry('/', '/')]);
    });

    test('names containing spaces and dots survive intact', () {
      expect(breadcrumbSegments('/home/mali/.ssh/my keys'), const [
        BreadcrumbEntry('/', '/'),
        BreadcrumbEntry('home', '/home'),
        BreadcrumbEntry('mali', '/home/mali'),
        BreadcrumbEntry('.ssh', '/home/mali/.ssh'),
        BreadcrumbEntry('my keys', '/home/mali/.ssh/my keys'),
      ]);
    });
  });
}
