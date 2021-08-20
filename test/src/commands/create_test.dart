import 'dart:async';
import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:devign_cli/src/command_runner.dart';
import 'package:devign_cli/src/commands/create.dart';
import 'package:devign_cli/src/templates/templates.dart';

const expectedUsage = [
  // ignore: no_adjacent_strings_in_list
  'Creates a new devign project in the specified directory.\n'
      '\n'
      'Usage: devign create <output directory>\n'
      '-h, --help                    Print this usage information.\n'
      '''    --project-name            The project name for this new project. This must be a valid dart package name.\n'''
      '    --desc                    The description for this new project.\n'
      '''                              (defaults to "A Devign Project created by Devign CLI.")\n'''
      '    --org-name                The organization for this new project.\n'
      '                              (defaults to "com.example.devigncore")\n'
      '''-t, --template                The template used to generate this new project.\n'''
      '\n'
      '''          [core] (default)    Generate a Devign Flutter application.\n'''
      '          [dart_pkg]          Generate a reusable Dart package.\n'
      '          [flutter_pkg]       Generate a reusable Flutter package.\n'
      '\n'
      'Run "devign help" to see global options.'
];

class MockArgResults extends Mock implements ArgResults {}

class MockLogger extends Mock implements Logger {}

class MockMasonGenerator extends Mock implements MasonGenerator {}

class FakeDirectoryGeneratorTarget extends Fake
    implements DirectoryGeneratorTarget {}

void main() {
  group('Create', () {
    late List<String> progressLogs;
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

    setUpAll(() {
      registerFallbackValue(FakeDirectoryGeneratorTarget());
    });

    setUp(() {
      printLogs = [];
      progressLogs = <String>[];
      logger = MockLogger();
      when(() => logger.progress(any())).thenReturn(
        ([_]) {
          if (_ != null) progressLogs.add(_);
        },
      );
      commandRunner = DevignCommandRunner(
        logger: logger,
      );
    });

    test('help', overridePrint(() async {
      final result = await commandRunner.run(['create', '--help']);
      expect(printLogs, equals(expectedUsage));
      expect(result, equals(ExitCode.success.code));

      printLogs.clear();

      final resultAbbr = await commandRunner.run(['create', '-h']);
      expect(printLogs, equals(expectedUsage));
      expect(resultAbbr, equals(ExitCode.success.code));
    }));

    test('can be instantiated without explicit logger', () {
      final command = CreateCommand();
      expect(command, isNotNull);
    });

    test(
        'throws UsageException when --project-name is missing '
        'and directory base is not a valid package name', () async {
      const expectedErrorMessage = '".tmp" is not a valid package name.\n\n'
          'See https://dart.dev/tools/pub/pubspec#name for more information.';
      final result = await commandRunner.run(['create', '.tmp']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(expectedErrorMessage)).called(1);
    });

    test('throws UsageException when --project-name is invalid', () async {
      const expectedErrorMessage = '"My App" is not a valid package name.\n\n'
          'See https://dart.dev/tools/pub/pubspec#name for more information.';
      final result = await commandRunner.run(
        ['create', '.', '--project-name', 'My App'],
      );
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(expectedErrorMessage)).called(1);
    });

    test('throws UsageException when output directory is missing', () async {
      const expectedErrorMessage =
          'No option specified for the output directory.';
      final result = await commandRunner.run(['create']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(expectedErrorMessage)).called(1);
    });

    test('throws UsageException when multiple output directories are provided',
        () async {
      const expectedErrorMessage = 'Multiple output directories specified.';
      final result = await commandRunner.run(['create', './a', './b']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(expectedErrorMessage)).called(1);
    });

    test('completes successfully with correct output', () async {
      final argResults = MockArgResults();
      final generator = MockMasonGenerator();
      final command = CreateCommand(
        logger: logger,
        generator: (_) async => generator,
      )..argResultOverrides = argResults;
      when(() => argResults['project-name'] as String?).thenReturn('my_app');
      when(() => argResults.rest).thenReturn(['.tmp']);
      when(() => generator.id).thenReturn('generator_id');
      when(() => generator.description).thenReturn('generator description');
      when(
        () => generator.generate(any(), vars: any(named: 'vars')),
      ).thenAnswer((_) async => 62);
      final result = await command.run();
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.progress('Bootstrapping')).called(1);
      expect(progressLogs, equals(['Generated 62 file(s)']));
      verify(
        () => logger.progress('Running "flutter packages get" in .tmp'),
      ).called(1);
      verify(() => logger.alert('Created a Devign App! 🦄')).called(1);
      verify(
        () => generator.generate(
          any(
            that: isA<DirectoryGeneratorTarget>().having(
              (g) => g.dir.path,
              'dir',
              '.tmp',
            ),
          ),
          vars: <String, dynamic>{
            'project_name': 'my_app',
            'org_name': [
              {'value': 'com', 'separator': '.'},
              {'value': 'example', 'separator': '.'},
              {'value': 'devigncore', 'separator': ''}
            ],
            'description': '',
          },
        ),
      ).called(1);
    });

    test('completes successfully w/ custom description', () async {
      final argResults = MockArgResults();
      final generator = MockMasonGenerator();
      final command = CreateCommand(
        logger: logger,
        generator: (_) async => generator,
      )..argResultOverrides = argResults;
      when(() => argResults['project-name'] as String?).thenReturn('my_app');
      when(
        () => argResults['desc'] as String?,
      ).thenReturn('devign description');
      when(() => argResults.rest).thenReturn(['.tmp']);
      when(() => generator.id).thenReturn('generator_id');
      when(() => generator.description).thenReturn('generator description');
      when(
        () => generator.generate(any(), vars: any(named: 'vars')),
      ).thenAnswer((_) async => 62);
      final result = await command.run();
      expect(result, equals(ExitCode.success.code));
      verify(
        () => generator.generate(
          any(
            that: isA<DirectoryGeneratorTarget>().having(
              (g) => g.dir.path,
              'dir',
              '.tmp',
            ),
          ),
          vars: <String, dynamic>{
            'project_name': 'my_app',
            'org_name': [
              {'value': 'com', 'separator': '.'},
              {'value': 'example', 'separator': '.'},
              {'value': 'devigncore', 'separator': ''}
            ],
            'description': 'devign description',
          },
        ),
      ).called(1);
    });

    group('org-name', () {
      group('invalid --org-name', () {
        Future<void> expectInvalidOrgName(String orgName) async {
          final expectedErrorMessage = '"$orgName" is not a valid org name.\n\n'
              'A valid org name has at least 2 parts separated by "."\n'
              'Each part must start with a letter and only include '
              'alphanumeric characters (A-Z, a-z, 0-9), underscores (_), '
              'and hyphens (-)\n'
              '(ex. devign.de)';
          final result = await commandRunner.run(
            ['create', '.', '--org-name', orgName],
          );
          expect(result, equals(ExitCode.usage.code));
          verify(() => logger.err(expectedErrorMessage)).called(1);
        }

        test('no delimiters', () {
          expectInvalidOrgName('My App');
        });

        test('less than 2 domains', () {
          expectInvalidOrgName('devignbadtest');
        });

        test('invalid characters present', () {
          expectInvalidOrgName('devign%.bad@.#test');
        });

        test('segment starts with a non-letter', () {
          expectInvalidOrgName('devign.bad.1test');
        });

        test('valid prefix but invalid suffix', () {
          expectInvalidOrgName('dev.ign.prefix.bad@@suffix');
        });
      });

      group('valid --org-name', () {
        Future<void> expectValidOrgName(
          String orgName,
          List<Map<String, String>> expected,
        ) async {
          final argResults = MockArgResults();
          final generator = MockMasonGenerator();
          final command = CreateCommand(
            logger: logger,
            generator: (_) async => generator,
          )..argResultOverrides = argResults;
          when(
            () => argResults['project-name'] as String?,
          ).thenReturn('my_app');
          when(() => argResults['org-name'] as String?).thenReturn(orgName);
          when(() => argResults.rest).thenReturn(['.tmp']);
          when(() => generator.id).thenReturn('generator_id');
          when(() => generator.description).thenReturn('generator description');
          when(
            () => generator.generate(any(), vars: any(named: 'vars')),
          ).thenAnswer((_) async => 62);
          final result = await command.run();
          expect(result, equals(ExitCode.success.code));
          verify(
            () => generator.generate(
              any(
                that: isA<DirectoryGeneratorTarget>().having(
                  (g) => g.dir.path,
                  'dir',
                  '.tmp',
                ),
              ),
              vars: <String, dynamic>{
                'project_name': 'my_app',
                'description': '',
                'org_name': expected
              },
            ),
          ).called(1);
        }

        test('alphanumeric with three parts', () async {
          await expectValidOrgName('dev.ign.ventures', [
            {'value': 'dev', 'separator': '.'},
            {'value': 'ign', 'separator': '.'},
            {'value': 'ventures', 'separator': ''},
          ]);
        });

        test('containing an underscore', () async {
          await expectValidOrgName('dev.ign.test_case', [
            {'value': 'dev', 'separator': '.'},
            {'value': 'ign', 'separator': '.'},
            {'value': 'test case', 'separator': ''},
          ]);
        });

        test('containing a hyphen', () async {
          await expectValidOrgName('devign.bad.test-case', [
            {'value': 'devign', 'separator': '.'},
            {'value': 'bad', 'separator': '.'},
            {'value': 'test case', 'separator': ''},
          ]);
        });

        test('single character parts', () async {
          await expectValidOrgName('d.v.n', [
            {'value': 'd', 'separator': '.'},
            {'value': 'v', 'separator': '.'},
            {'value': 'n', 'separator': ''},
          ]);
        });

        test('more than three parts', () async {
          await expectValidOrgName('de.vi.gn.app.identifier', [
            {'value': 'de', 'separator': '.'},
            {'value': 'vi', 'separator': '.'},
            {'value': 'gn', 'separator': '.'},
            {'value': 'app', 'separator': '.'},
            {'value': 'identifier', 'separator': ''},
          ]);
        });

        test('less than three parts', () async {
          await expectValidOrgName('dev.ign', [
            {'value': 'dev', 'separator': '.'},
            {'value': 'ign', 'separator': ''},
          ]);
        });
      });
    });

    group('--template', () {
      group('invalid template name', () {
        Future<void> expectInvalidTemplateName(String templateName) async {
          final expectedErrorMessage =
              '"$templateName" is not an allowed value for option "template".';
          final result = await commandRunner.run(
            ['create', '.', '--template', templateName],
          );
          expect(result, equals(ExitCode.usage.code));
          verify(() => logger.err(expectedErrorMessage)).called(1);
        }

        test('invalid template name', () {
          expectInvalidTemplateName('badtemplate');
        });
      });

      group('valid template names', () {
        Future<void> expectValidTemplateName({
          required String getPackagesMsg,
          required String templateName,
          required MasonBundle expectedBundle,
          required String expectedLogSummary,
        }) async {
          final argResults = MockArgResults();
          final generator = MockMasonGenerator();
          final command = CreateCommand(
            logger: logger,
            generator: (bundle) async {
              expect(bundle, equals(expectedBundle));
              return generator;
            },
          )..argResultOverrides = argResults;
          when(
            () => argResults['project-name'] as String?,
          ).thenReturn('my_app');
          when(
            () => argResults['template'] as String?,
          ).thenReturn(templateName);
          when(() => argResults.rest).thenReturn(['.tmp']);
          when(() => generator.id).thenReturn('generator_id');
          when(() => generator.description).thenReturn('generator description');
          when(
            () => generator.generate(any(), vars: any(named: 'vars')),
          ).thenAnswer((_) async => 62);
          final result = await command.run();
          expect(result, equals(ExitCode.success.code));
          verify(() => logger.progress('Bootstrapping')).called(1);
          expect(progressLogs, equals(['Generated 62 file(s)']));
          verify(
            () => logger.progress(getPackagesMsg),
          ).called(1);
          verify(() => logger.alert(expectedLogSummary)).called(1);
          verify(
            () => generator.generate(
              any(
                that: isA<DirectoryGeneratorTarget>().having(
                  (g) => g.dir.path,
                  'dir',
                  '.tmp',
                ),
              ),
              vars: <String, dynamic>{
                'project_name': 'my_app',
                'org_name': [
                  {'value': 'com', 'separator': '.'},
                  {'value': 'example', 'separator': '.'},
                  {'value': 'devigncore', 'separator': ''}
                ],
                'description': '',
              },
            ),
          ).called(1);
        }

        test('core template', () async {
          await expectValidTemplateName(
            getPackagesMsg: 'Running "flutter packages get" in .tmp',
            templateName: 'core',
            expectedBundle: devignCoreBundle,
            expectedLogSummary: 'Created a Devign App! 🦄',
          );
        });

        test('dart pkg template', () async {
          await expectValidTemplateName(
            getPackagesMsg: 'Running "flutter pub get" in .tmp',
            templateName: 'dart_pkg',
            expectedBundle: dartPackageBundle,
            expectedLogSummary: 'Created a Devign Dart package! 🦄',
          );
        });

        test('flutter pkg template', () async {
          await expectValidTemplateName(
            getPackagesMsg: 'Running "flutter packages get" in .tmp',
            templateName: 'flutter_pkg',
            expectedBundle: flutterPackageBundle,
            expectedLogSummary: 'Created a Devign Flutter package! 🦄',
          );
        });
      });
    });
  });
}
