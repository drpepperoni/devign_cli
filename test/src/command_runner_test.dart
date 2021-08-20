// ignore_for_file: no_adjacent_strings_in_list
import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:devign_cli/src/command_runner.dart';
import 'package:devign_cli/src/version.dart';

class MockLogger extends Mock implements Logger {}

const expectedUsage = [
  '🦄 A Devign Command Line Interface\n'
      '\n'
      'Usage: devign <command> [arguments]\n'
      '\n'
      'Global options:\n'
      '-h, --help           Print this usage information.\n'
      '    --version        Print the current version.\n'
      '\n'
      '          [false]    Disable anonymous usage statistics\n'
      '          [true]     Enable anonymous usage statistics\n'
      '\n'
      'Available commands:\n'
      '  create   devign create <output directory>\n'
      '''           Creates a new devign project in the specified directory.\n'''
      '\n'
      'Run "devign help <command>" for more information about a command.'
];

void main() {
  group('DevignCommandRunner', () {
    late List<String> printLogs;
    late Logger logger;
    late DevignCommandRunner commandRunner;

    void Function() overridePrint(void Function() fn) {
      return () {
        final spec = ZoneSpecification(print: (_, __, ___, String msg) {
          printLogs.add(msg);
        });
        return Zone.current.fork(specification: spec).run<void>(fn);
      };
    }

    setUp(() {
      printLogs = [];
      logger = MockLogger();
      commandRunner = DevignCommandRunner(
        logger: logger,
      );
    });

    group('run', () {
      test('handles FormatException', () async {
        const exception = FormatException('oops!');
        var isFirstInvocation = true;
        when(() => logger.info(any())).thenAnswer((_) {
          if (isFirstInvocation) {
            isFirstInvocation = false;
            throw exception;
          }
        });
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(exception.message)).called(1);
        verify(() => logger.info(commandRunner.usage)).called(1);
      });

      test('handles UsageException', () async {
        final exception = UsageException('oops!', commandRunner.usage);
        var isFirstInvocation = true;
        when(() => logger.info(any())).thenAnswer((_) {
          if (isFirstInvocation) {
            isFirstInvocation = false;
            throw exception;
          }
        });
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(exception.message)).called(1);
        verify(() => logger.info(commandRunner.usage)).called(1);
      });

      test('handles no command', overridePrint(() async {
        final result = await commandRunner.run([]);
        expect(printLogs, equals(expectedUsage));
        expect(result, equals(ExitCode.success.code));
      }));

      group('--help', () {
        test('outputs usage', overridePrint(() async {
          final result = await commandRunner.run(['--help']);
          expect(printLogs, equals(expectedUsage));
          expect(result, equals(ExitCode.success.code));

          printLogs.clear();

          final resultAbbr = await commandRunner.run(['-h']);
          expect(printLogs, equals(expectedUsage));
          expect(resultAbbr, equals(ExitCode.success.code));
        }));
      });

      group('--version', () {
        test('outputs current version', () async {
          final result = await commandRunner.run(['--version']);
          expect(result, equals(ExitCode.success.code));
          verify(() => logger.info('devign version: $packageVersion'));
        });
      });
    });
  });
}
