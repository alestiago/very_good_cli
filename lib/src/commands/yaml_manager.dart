// TODO(alestiago): Move file location to a better place.

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart';

class YamlFileNotFound implements Exception {}

@immutable
class YamlFile {
  YamlFile({
    String cwd = '.',
    String fileName = 'pubspec.yaml',
  }) : _file = File(p.join(cwd, fileName));

  final File _file;

  Future<bool> get exists => _file.exists();

  /// Returns the [YamlMap] of the file.
  Future<YamlMap> read() async {
    if (await _file.exists()) {
      final contents = await _file.readAsString();
      return loadYaml(contents) as YamlMap;
    }

    throw YamlFileNotFound();
  }
}
