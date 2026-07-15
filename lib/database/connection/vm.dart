import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// In-memory executor used by the Dart VM test suite only.
QueryExecutor openConnection() => NativeDatabase.memory();
