class AppException implements Exception {
  const AppException(this.code);
  final String code;
}

class NetworkException extends AppException {
  const NetworkException() : super('network');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('unauthorized');
}

class ForbiddenException extends AppException {
  const ForbiddenException() : super('forbidden');
}

class NotFoundException extends AppException {
  const NotFoundException() : super('not_found');
}

class ValidationException extends AppException {
  const ValidationException() : super('validation');
}

class ServerException extends AppException {
  const ServerException() : super('server');
}

class InvalidResponseException extends AppException {
  const InvalidResponseException() : super('invalid_response');
}
