/// Shared Result class for operations
class Result<T> {

  factory Result.error(String error, {String? errorCode}) {
    return Result._(
      data: null,
      error: error,
      errorCode: errorCode,
      success: false,
    );
  }

  factory Result.success(T data) {
    return Result._(
      data: data,
      error: null,
      errorCode: null,
      success: true,
    );
  }

  const Result._({
    required this.data,
    required this.error,
    required this.errorCode,
    required this.success,
  });

  final T? data;
  final String? error;
  final String? errorCode;
  final bool success;

  bool get isSuccess => success;
  bool get hasError => !success;
} 