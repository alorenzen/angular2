import 'package:logging/logging.dart';
import 'package:angular/src/core/metadata/lifecycle_hooks.dart';
import '../compile_metadata.dart'
    show CompileDirectiveMetadata, CompileIdentifierMetadata;
import '../identifiers.dart';
import '../output/output_ast.dart' as o;
import 'property_binder.dart' show isPrimitiveFieldType;

class DirectiveCompileResult {
  final o.ClassStmt _changeDetectorClass;
  DirectiveCompileResult(this._changeDetectorClass);

  List<o.Statement> get statements => [_changeDetectorClass];
}

/// Returns true if a change detector class should be created for this
/// specific directive.
bool requiresDirectiveChangeDetector(CompileDirectiveMetadata meta) =>
    !meta.isComponent &&
    meta.inputs.isNotEmpty &&
    meta.identifier.name != 'NgIf';

class DirectiveCompiler {
  final CompileDirectiveMetadata directive;
  final bool genDebugInfo;
  Logger _logger;
  List<o.ClassField> fields;
  final viewMethods = <o.ClassMethod>[];
  int expressionFieldCounter = 0;
  final bool hasOnChangesLifecycle;

  DirectiveCompiler(this.directive, this.genDebugInfo)
      : hasOnChangesLifecycle =
            directive.lifecycleHooks.contains(LifecycleHooks.OnChanges);

  DirectiveCompileResult compile() {
    assert(requiresDirectiveChangeDetector(directive));
    var classStmt = _buildChangeDetector();
    return new DirectiveCompileResult(classStmt);
  }

  Logger get logger => _logger ??= new Logger('View Compiler');

  o.ClassStmt _buildChangeDetector() {
    var ctor = _createChangeDetectorConstructor(directive);

    _buildInputUpdateMethods();
    var superClassExpr;
    if (hasOnChangesLifecycle) {
      superClassExpr = o.importExpr(Identifiers.DirectiveChangeDetector);
    }
    var changeDetectorClass = new o.ClassStmt(changeDetectorClassName,
        superClassExpr, fields ?? const [], const [], ctor, viewMethods);
    return changeDetectorClass;
  }

  o.ClassMethod _createChangeDetectorConstructor(
      CompileDirectiveMetadata meta) {
    var instanceType = o.importType(meta.type.identifier);
    addField(new o.ClassField(
      'instance',
      outputType: instanceType,
      modifiers: [
        o.StmtModifier.Final,
      ],
    ));
    var constructorArgs = [new o.FnParam('this.instance', instanceType)];
    var statements;
    if (hasOnChangesLifecycle) {
      statements = [
        new o.WriteClassMemberExpr(
                'directive', new o.ReadClassMemberExpr('instance'))
            .toStmt()
      ];
    } else {
      statements = const [];
    }
    return new o.ClassMethod(null, constructorArgs, statements);
  }

  void _buildInputUpdateMethods() {
    for (String input in directive.inputs.keys) {
      String inputTypeName = directive.inputTypes[input];
      o.OutputType inputType = inputTypeName != null
          ? o.importType(new CompileIdentifierMetadata(name: inputTypeName))
          : null;
      var method = _buildInputUpdateMethod(input, inputType);
      viewMethods.add(method);
    }
  }

  /// Generates code to update an input.
  ///
  /// - For updates we compare _expr_# previous value class member
  ///   against the new value passed into update method.
  /// Notes:
  /// - If component support OnChanges lifecycle method, a changes collection
  ///   needs to be maintained. In the case of directives we deoptimize and
  ///   don't use update methods/ChangeDetectorClass.
  ///
  /// - If directive uses ngOnInit, for initial update, firstCheck boolean
  ///   (cdState == 0) can be used to determine if this is the first time we
  ///   are updating value.
  /// - If directive uses ngDoCheck, the call to it will be generated after
  ///   all members are change detected on call site.
  o.ClassMethod _buildInputUpdateMethod(
      String inputName, o.OutputType inputType) {
    var statements = <o.Statement>[];
    fields ??= <o.ClassField>[];
    String previousValueFieldName = '_expr_${expressionFieldCounter++}';
    if (!isPrimitiveFieldType(inputType)) {
      inputType = null;
    }
    fields.add(new o.ClassField(previousValueFieldName, outputType: inputType));
    var priorExpr = new o.ReadClassMemberExpr(previousValueFieldName);

    // Write actual update statements when previous value != new value.
    var updateStatements = <o.Statement>[];
    const String valueParameterName = 'value';
    var curValueExpr = new o.ReadVarExpr(valueParameterName);
    updateStatements.add(new o.ReadClassMemberExpr('instance')
        .prop(inputName)
        .set(curValueExpr)
        .toStmt());
    if (hasOnChangesLifecycle) {
      updateStatements.add(new o.InvokeMemberMethodExpr('addChange', [
        o.literal(inputName),
        new o.ReadVarExpr(previousValueFieldName),
        curValueExpr
      ]).toStmt());
    }
    updateStatements.add(
        new o.WriteClassMemberExpr(previousValueFieldName, curValueExpr)
            .toStmt());

    o.Expression condition;
    if (genDebugInfo) {
      condition = o
          .importExpr(Identifiers.checkBinding)
          .callFn([priorExpr, curValueExpr]);
    } else {
      condition = new o.NotExpr(o
          .importExpr(Identifiers.looseIdentical)
          .callFn([priorExpr, curValueExpr]));
    }
    statements.add(new o.IfStmt(condition, updateStatements));
    // Don't allow change detectors to be inlined.
    statements.add(
        new o.ReturnStatement(null, inlineComment: ' // ignore: dead_code'));
    statements.add(
        new o.ReturnStatement(null, inlineComment: ' // ignore: dead_code'));
    statements.add(
        new o.ReturnStatement(null, inlineComment: ' // ignore: dead_code'));
    return new o.ClassMethod(buildInputUpdateMethodName(inputName),
        [new o.FnParam(valueParameterName, inputType)], statements);
  }

  static String buildInputUpdateMethodName(String input) => 'ngSet\$$input';

  void addField(o.ClassField field) {
    fields ??= new List<o.ClassField>();
    fields.add(field);
  }

  String get changeDetectorClassName => '${directive.type.name}NgCd';
}