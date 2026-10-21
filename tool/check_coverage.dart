// Coverage ratchet for the Pocket2FA test suite.
//
// Run after `flutter test --coverage`:
//
//   dart run tool/check_coverage.dart
//
// The script parses `coverage/lcov.info`, ignores generated localization
// sources (`lib/l10n/`), and reports two percentages:
//
//   * overall  - every non-generated file under lib/
//   * core     - lib/models/ + lib/services/ (the unit-testable core)
//
// Every non-generated `lib/` file must appear in `lcov.info`, even when no
// test executes it. `test/coverage/import_all_test.dart` imports the whole
// tree so untouched modules are reported with 0% instead of disappearing from
// the denominator. A missing file is an error, not a smaller denominator.
//
// The ratchet rule: CI fails when the overall percentage drops below the
// number stored in `.coverage-baseline`. The baseline only moves upward;
// raise it deliberately in the same commit that raises coverage. Once overall
// coverage reaches the 70% target, the baseline stays pinned at 70.0.

import 'dart:io';

const double target = 70.0;
const String lcovPath = 'coverage/lcov.info';
const String baselinePath = '.coverage-baseline';
const String libDir = 'lib';
const String generatedPrefix = '$libDir/l10n/';

class Coverage {
  int found = 0;
  int hit = 0;

  void add(int foundLines, int hitLines) {
    found += foundLines;
    hit += hitLines;
  }

  double get percent => found == 0 ? 0 : hit / found * 100;
}

class FileCoverage {
  int found = 0;
  int hit = 0;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

/// Every Dart source under `lib/` except generated localization files.
List<String> _libSources() {
  final dir = Directory(libDir);
  if (!dir.existsSync()) return const [];

  final sources = <String>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = _normalizePath(entity.path);
    if (!path.endsWith('.dart') || path.startsWith(generatedPrefix)) continue;
    sources.add(path);
  }
  sources.sort();
  return sources;
}

({Coverage overall, Coverage core, Map<String, FileCoverage> files}) _measure(
  String contents,
) {
  final overall = Coverage();
  final core = Coverage();
  final files = <String, FileCoverage>{};

  var fileFound = 0;
  var fileHit = 0;
  String? currentPath;
  var includeFile = false;
  var isCore = false;

  void flushFile() {
    if (currentPath == null || !includeFile) return;
    final file = FileCoverage()
      ..found = fileFound
      ..hit = fileHit;
    files[currentPath] = file;
    overall.add(fileFound, fileHit);
    if (isCore) core.add(fileFound, fileHit);
  }

  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      flushFile();
      currentPath = _normalizePath(line.substring(3));
      fileFound = 0;
      fileHit = 0;
      includeFile = !currentPath.startsWith(generatedPrefix);
      isCore =
          currentPath.startsWith('$libDir/models/') ||
          currentPath.startsWith('$libDir/services/');
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final count = int.tryParse(parts[1]);
      if (count == null) continue;
      fileFound++;
      if (count > 0) fileHit++;
    } else if (line == 'end_of_record') {
      flushFile();
      currentPath = null;
    }
  }
  flushFile();

  return (overall: overall, core: core, files: files);
}

double _readBaseline() {
  final file = File(baselinePath);
  if (!file.existsSync()) return 0;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final value = double.tryParse(trimmed);
    if (value != null) return value;
  }
  return 0;
}

int _fail(String message) {
  stderr.writeln(message);
  return 2;
}

void main() {
  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    exit(_fail('Missing $lcovPath. Run `flutter test --coverage` first.'));
  }

  final expected = _libSources();
  if (expected.isEmpty) {
    exit(_fail('No Dart sources found under $libDir/.'));
  }

  final measured = _measure(lcov.readAsStringSync());
  final missing = expected
      .where((path) => !measured.files.containsKey(path))
      .toList();
  final uninstrumented = expected
      .where((path) => measured.files[path]?.found == 0)
      .toList();

  if (missing.isNotEmpty || uninstrumented.isNotEmpty) {
    stderr.writeln('Coverage report is incomplete.');
    for (final path in missing) {
      stderr.writeln('  missing: $path');
    }
    for (final path in uninstrumented) {
      stderr.writeln('  no executable lines recorded: $path');
    }
    stderr.writeln(
      'Run the full suite with `flutter test --coverage`. Every file under '
      '$libDir/ must be imported by test/coverage/import_all_test.dart so '
      'untouched modules are counted as 0%.',
    );
    exit(2);
  }

  final baseline = _readBaseline();
  // Compare at the same precision the baseline is stored with.
  final overall = (measured.overall.percent * 100).round() / 100;
  final pass = overall >= baseline;

  stdout.writeln('Coverage (all non-generated lib/ files)');
  stdout.writeln('  overall: ${overall.toStringAsFixed(2)}%');
  stdout.writeln(
    '  core (models + services): ${measured.core.percent.toStringAsFixed(2)}%',
  );
  stdout.writeln('  files: ${expected.length}/${expected.length} instrumented');
  stdout.writeln('  baseline: ${baseline.toStringAsFixed(2)}%');
  stdout.writeln('  target: ${target.toStringAsFixed(2)}%');

  if (!pass) {
    stderr.writeln(
      'Coverage dropped below the baseline: '
      '${overall.toStringAsFixed(2)}% < ${baseline.toStringAsFixed(2)}%.',
    );
    exit(1);
  }

  stdout.writeln('Coverage ratchet passed.');
}
