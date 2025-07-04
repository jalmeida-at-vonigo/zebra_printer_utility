import '../../models/result.dart';

/// Abstract base class for all commands in the command pattern
abstract class BaseCommand<T> {
  /// Execute the command and return a Result
  Future<Result<T>> execute();
  
  /// Human-readable name for the operation
  String get operationName;
} 