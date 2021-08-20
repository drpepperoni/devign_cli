import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:mason/mason.dart';
import 'package:devign_cli/src/commands/commands.dart';
import 'package:devign_cli/src/version.dart';

/// {@template devign_command_runner}
/// A [CommandRunner] for the Devign CLI.
/// {@endtemplate}
class DevignCommandRunner extends CommandRunner<int> {
  /// {@macro devign_command_runner}
  DevignCommandRunner({Logger? logger})
      : _logger = logger ?? Logger(),
        super('devign', '🦄 A Devign Command Line Interface') {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the current version.',
    );
    addCommand(CreateCommand(logger: logger));
  }

  /// Standard timeout duration for the CLI.
  static const timeout = Duration(milliseconds: 500);

  final Logger _logger;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final _argResults = parse(args);
      return await runCommand(_argResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.info('devign version: $packageVersion');
      return ExitCode.success.code;
    }
    return super.runCommand(topLevelResults);
  }
}
