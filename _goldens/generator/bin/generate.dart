import 'dart:async';

import 'package:angular/src/source_gen/template_compiler/generator.dart';
import 'package:angular_compiler/angular_compiler.dart';
import 'package:args/args.dart';
import 'package:build_runner/build_runner.dart';
import 'package:source_gen/source_gen.dart';

const testFiles = 'test_files';

const _updateGoldens = 'update-goldens';
const _useAstPkg = 'use_ast';

/// This script runs the source_gen test generators. This is required before the
/// tests can run, since they check the output of these generators against
/// golden files.
///
/// To update the golden files, in the root angular _goldens directory, run
/// `pub get` and then
/// `dart generator/bin/generate.dart --update-goldens`
Future main(List<String> args) async {
  var parser = new ArgParser()
    ..addFlag(_updateGoldens, defaultsTo: false)..addFlag(
        _useAstPkg, defaultsTo: false);
  var results = parser.parse(args);
  var updateGoldens = results[_updateGoldens];
  var useAstPkg = results[_useAstPkg];
  var package = '_goldens';
  // var inputs = ['$testFiles/*.dart', '$testFiles/**/*.dart'];
  var inputs = ['$testFiles/directives/components.dart'];
  var buildActions = [
    new BuildAction(
        new LibraryBuilder(
            new TemplateGenerator(new CompilerFlags(
                genDebugInfo: false,
                usePlaceholder: false,
                useAstPkg: useAstPkg ?? false)),
            generatedExtension: updateGoldens
                ? '.template_release.golden'
                : '.template_release.check'),
        package,
        inputs: inputs),
    new BuildAction(
        new LibraryBuilder(
            new TemplateGenerator(new CompilerFlags(
                genDebugInfo: true,
                usePlaceholder: false,
                useAstPkg: useAstPkg ?? false)),
            generatedExtension: updateGoldens
                ? '.template_debug.golden'
                : '.template_debug.check'),
        package,
        inputs: inputs),
    new BuildAction(
        new TemplateOutliner(
            const CompilerFlags(genDebugInfo: false, usePlaceholder: false),
            extension: updateGoldens
                ? '.template_outline.golden'
                : '.template_outline.check'),
        package,
        inputs: inputs)
  ];
  await build(buildActions, deleteFilesByDefault: updateGoldens);
}
