import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';
import 'package:very_good_cli/src/commands/yaml_manager.dart';
import 'package:yaml/yaml.dart';

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
    final scriptsYaml = YamlFile(fileName: 'scripts.yaml');
    final pubspecYaml = YamlFile();

    late final List<_Script> scripts;

    if (await scriptsYaml.exists) {
      scripts = await scriptsYaml.parseScripts();
    } else if (await pubspecYaml.exists) {
      scripts = await pubspecYaml.parseScripts();
    } else {
      throw UsageException('No scripts.yaml or pubspec.yaml found.', usage);
    }

    if (scriptName == null) {
      _listScripts(scripts);
    } else {
      final script = scripts.where((script) => script.name == scriptName);
      if (script.isEmpty) {
        throw UsageException('Script "$scriptName" not found', usage);
      } else {
        await script.first(_logger);
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

extension _YamlX on YamlFile {
  static const _scriptsTag = 'scripts';

  Future<List<_Script>> parseScripts() async {
    // TODO(alestiago): Throw error if failed.
    final yamlMap = await read();

    if (!yamlMap.value.containsKey(_scriptsTag)) {
      throw UsageException(
        'No scripts found',
        'Ensure that scripts are defined in scripts.yaml or pubspec.yaml',
      );
    }

    if (yamlMap.value[_scriptsTag] is! YamlList) {
      throw UsageException(
        'Scripts follow invalid format.',
        'Ensure scripts are defined as a list',
      );
    }

    final yamlScripts = yamlMap.value[_scriptsTag] as YamlList;
    final scripts = <_Script>[];

    for (final element in yamlScripts.value) {
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
    } else if (command is YamlList) {
      final commands = command.value.map((dynamic e) => e as String).toList();
      return _Script(name: name, commands: commands);
    } else {
      throw Exception('Found $name, but no commands.');
    }
  }

  final String name;
  final List<String> commands;

  Future<void> call(Logger logger) async {
    for (final command in commands) {
      // TODO(alestiago): Allow specifing working directory.
      final arguments = command.split(' ');
      final commandName = arguments.removeAt(0);

      final process = await Process.start(
        commandName,
        arguments,
        runInShell: true,
      );
      await for (final events in process.stdout.transform(utf8.decoder)) {
        print(events);
      }
    }
  }
}
