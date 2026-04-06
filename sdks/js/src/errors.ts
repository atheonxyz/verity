/** Error codes matching the C FFI VerityError enum. */
export enum VerityErrorCode {
  NOT_INITIALIZED = -1,
  INVALID_INPUT = 1,
  SCHEME_READ_ERROR = 2,
  WITNESS_READ_ERROR = 3,
  PROOF_ERROR = 4,
  SERIALIZATION_ERROR = 5,
  UTF8_ERROR = 6,
  FILE_WRITE_ERROR = 7,
  /** @deprecated Reserved (formerly circuit compilation). */
  COMPILATION_ERROR = 8,
  UNKNOWN_BACKEND = 9,
  BACKEND_UNAVAILABLE = 10,
}

/** Typed error for Verity operations. */
export class VerityError extends Error {
  readonly code: VerityErrorCode;

  constructor(code: VerityErrorCode, detail?: string) {
    const message = detail
      ? `${VerityError.messageForCode(code)}: ${detail}`
      : VerityError.messageForCode(code);
    super(message);
    this.name = "VerityError";
    this.code = code;
  }

  private static messageForCode(code: VerityErrorCode): string {
    switch (code) {
      case VerityErrorCode.NOT_INITIALIZED:
        return "Verity not initialized";
      case VerityErrorCode.INVALID_INPUT:
        return "Invalid input";
      case VerityErrorCode.SCHEME_READ_ERROR:
        return "Failed to read scheme/circuit file";
      case VerityErrorCode.WITNESS_READ_ERROR:
        return "Witness read error";
      case VerityErrorCode.PROOF_ERROR:
        return "Proof generation or verification error";
      case VerityErrorCode.SERIALIZATION_ERROR:
        return "Serialization error";
      case VerityErrorCode.UTF8_ERROR:
        return "UTF-8 error";
      case VerityErrorCode.FILE_WRITE_ERROR:
        return "File write error";
      case VerityErrorCode.COMPILATION_ERROR:
        return "Reserved error code";
      case VerityErrorCode.UNKNOWN_BACKEND:
        return "Unknown or unregistered backend";
      case VerityErrorCode.BACKEND_UNAVAILABLE:
        return "Backend not available in this runtime";
      default:
        return `FFI error code: ${code}`;
    }
  }

  /** Map an FFI error code to a VerityError. */
  static fromCode(code: number, detail?: string): VerityError {
    return new VerityError(code as VerityErrorCode, detail);
  }
}
