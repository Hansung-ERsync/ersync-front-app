class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.statusCode,
    this.traceId,
    this.fieldErrors = const <Object?>[],
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? traceId;
  final List<Object?> fieldErrors;

  @override
  String toString() => message;
}
