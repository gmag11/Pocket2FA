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
// The ratchet rule: CI fails when the overall percentage drops below the
// number stored in `.coverage-baseline`. The baseline only moves upward;
// raise it deliberately in the same commit that raises coverage. Once overall
// coverage reaches the 70% target, the baseline stays pinned at 70.0.

import 'dart:io';

const double target = 70.0;
const String lcovPath = 'coverage/lcov.info';
const String baselinePath = '.coverage-baseline';

class Coverage {
  int found = 0;
  int hit = 0;

  void add(int foundLines, int hitLines) {
    found += foundLines;
    hit += hitLines;
  }

  double get percent => found == 0 ? 0 : hit / found * 100;
}

({Coverage overall, Coverage core}) _measure(String contents) {
  final overall = Coverage();
  final core = Coverage();
  var fileFound = 0;
  var fileHit = 0;
  var inFile = false;
  var includeFile = false;
  var isCore = false;

  void flushFile() {
    if (!inFile || !includeFile) return;
    overall.add(fileFound, fileHit);
    if (isCore) core.add(fileFound, fileHit);
  }

  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      flushFile();
      final path = line.substring(3);
      inFile = true;
      fileFound = 0;
      fileHit = 0;
      includeFile = !path.contains('lib/l10n/');
      isCore =
          path.startsWith('lib/models/') || path.startsWith('lib/services/');
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final count = int.tryParse(parts[1]);
      if (count == null) continue;
      fileFound++;
      if (count > 0) fileHit++;
    } else if (line == 'end_of_record') {
      flushFile();
      inFile = false;
    }
  }
  flushFile();

  return (overall: overall, core: core);
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

  final measured = _measure(lcov.readAsStringSync());
  if (measured.overall.found == 0) {
    exit(_fail('No coverage records found in $lcovPath.'));
  }

  final baseline = _readBaseline();
  // Compare at the same precision the baseline is stored with.
  final overall = (measured.overall.percent * 100).round() / 100;
  final pass = overall >= baseline;

  stdout.writeln('Coverage (generated lib/l10n/ excluded)');
  stdout.writeln('  overall: ${overall.toStringAsFixed(2)}%');
  stdout.writeln(
    '  core (models + services): ${measured.core.percent.toStringAsFixed(2)}%',
  );
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
