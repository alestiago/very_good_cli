import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart' as y;

// TODO(alestiago): Refactor and clean.

/// {@template run_command}
/// `very_good run` command for managing scripts.
/// {@endtemplate}
class RunCommand extends Command<int> {
  /// {@macro run_command}
  RunCommand({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  @override
  String get description => 'Command for running scripts.';

  @override
  String get name => 'run';

  /// [ArgResults] which can be overridden for testing.
  @visibleForTesting
  ArgResults? argResultOverrides;

  ArgResults get _argResults => argResultOverrides ?? argResults!;

  @override
  Future<int> run() async {
    if (_argResults.rest.length > 1) {
      throw UsageException('Too many arguments', usage);
    }

    final scriptName =
        _argResults.rest.length == 1 ? _argResults.rest[0] : null;
    final pubspec = Pubspec();
    final scripts = await pubspec._availableSripts();

    if (scriptName == null) {
      _listScripts(scripts);
    } else {
      final script = scripts.where((script) => script.name == scriptName);
      if (script.isEmpty) {
        throw UsageException('Script "$scriptName" not found', usage);
      } else {
        await script.first();
      }
    }

    return ExitCode.success.code;
  }

  void _listScripts(List<_Script> scripts) {
    for (final script in scripts) {
      _logger.info(script.name);
      for (final command in script.commands) {
        _logger.detail('\r $command');
      }
    }
  }
}

@immutable
class Pubspec {
  const Pubspec({
    this.path = 'pubspec.yaml',
  });

  final String path;

  File _load() {
    // TODO(alestiago): Throw exception if pubspec.yaml does not exist.
    return File(path);
  }

  Future<Map> _loadYaml() async {
    // TODO(alestiago): Throw exception if pubspec.yaml has invalid format.
    final file = _load();
    final contents = file.readAsStringSync();
    return y.loadYaml(contents) as Map;
  }

  Future<dynamic> fetchTag(String tag) async {
    final yaml = await _loadYaml();
    return yaml[tag];
  }
}

extension _PubspecScript on Pubspec {
  Future<List<_Script>> _availableSripts() async {
    // TODO(alestiago): Thor error if failed.
    const pubspec = Pubspec();
    final yamlScripts = await pubspec.fetchTag('scripts') as List;
    final scripts = <_Script>[];

    for (final element in yamlScripts) {
      final scriptYaml = element as Map;
      final script = _Script.fromYaml(scriptYaml);
      scripts.add(script);
    }

    return scripts;
  }
}

class _Script {
  const _Script({
    required this.name,
    required this.commands,
  });

  factory _Script.fromYaml(Map yaml) {
    final name = yaml.keys.first as String;
    final commands = yaml.values;

    if (commands.isEmpty) {
      throw Exception('Found $name, but no commands.');
    }

    final command = commands.first as Object;
    if (command is String) {
      return _Script(name: name, commands: [command]);
    } else if (command is y.YamlList) {
      final commands = command.value.map((dynamic e) => e as String).toList();
      return _Script(name: name, commands: commands);
    } else {
      throw Exception('Found $name, but no commands.');
    }
  }

  final String name;
  final List<String> commands;

  Future<void> call() async {
    for (final command in commands) {
      await Process.run(
        command,
        [],
        // TODO(alestiago): Allow specifing working directory.
        // workingDirectory: workingDirectory,
        runInShell: true,
      );
    }
  }
}
