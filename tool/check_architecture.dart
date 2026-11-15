import 'dart:convert';
import 'dart:io';

/// Checks local Dart URIs and the migration map without contacting a backend.
void main() {
  final failures = <String>[];
  final workspace = Directory.current;
  final directives = RegExp(
    r'''^\s*(?:import|export|part(?:\s+of)?)\s+[\s\S]*?;''',
    multiLine: true,
  );
  final quotedUri = RegExp(r'''['"]([^'"\r\n]+)['"]''');
  var checked = 0;

  for (final folder in ['lib', 'test']) {
    for (final file in Directory(folder).listSync(recursive: true)) {
      if (file is! File ||
          (!file.path.endsWith('.dart') &&
              !file.path.endsWith('.dart.template'))) {
        continue;
      }
      checked++;
      final contents = file.readAsStringSync();
      for (final directive in directives.allMatches(contents)) {
        for (final match in quotedUri.allMatches(directive.group(0)!)) {
          final uri = match.group(1)!;
          final Uri target;
          if (uri.startsWith('package:cabine_flow/')) {
            target = workspace.uri.resolve('lib/${uri.substring(20)}');
          } else if (uri.startsWith('dart:') || uri.startsWith('package:')) {
            continue;
          } else {
            target = file.absolute.uri.resolve(uri);
          }
          if (!File.fromUri(target).existsSync()) {
            failures.add('${file.path}: unresolved URI $uri');
          }
        }
      }
    }
  }

  final manifest =
      jsonDecode(File('docs/architecture/path-map.json').readAsStringSync())
          as Map<String, dynamic>;
  final moves = manifest['moves'] as List<dynamic>;
  const compatibilityEntries = {
    'lib/main.dart',
    'lib/main_customer_web.dart',
    'lib/main_backoffice_web.dart',
  };
  final destinations = <String>{};
  var removed = 0;
  for (final entry in moves.cast<Map<String, dynamic>>()) {
    final from = entry['from'] as String;
    final to = entry['to'] as String;
    if (!destinations.add(to)) failures.add('Duplicate destination: $to');
    if (entry['status'] == 'removed') {
      removed++;
      if (File(to).existsSync()) {
        failures.add('Removed source still exists: $to');
      }
    } else if (!File(to).existsSync()) {
      failures.add('Missing destination: $to');
    }
    if (File(from).existsSync() && !compatibilityEntries.contains(from)) {
      failures.add('Old source still exists: $from');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Architecture OK: $checked Dart sources/templates, ${moves.length} moves, $removed removed sources.',
  );
}
