export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;

  constructor(message: string, statusCode: number, code: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}

export function badRequest(message: string, code = 'BAD_REQUEST'): never {
  throw new AppError(message, 400, code);
}

export function unauthorized(message: string, code = 'UNAUTHORIZED'): never {
  throw new AppError(message, 401, code);
}

export function forbidden(message: string, code = 'FORBIDDEN'): never {
  throw new AppError(message, 403, code);
}

export function notFound(message: string, code = 'NOT_FOUND'): never {
  throw new AppError(message, 404, code);
}

export function conflict(message: string, code = 'CONFLICT'): never {
  throw new AppError(message, 409, code);
}
