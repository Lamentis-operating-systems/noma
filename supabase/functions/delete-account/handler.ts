export interface AccountDeletionOperationError {
  message: string;
}

export interface AccountDeletionGateway {
  getUser(token: string): Promise<{
    user: { id: string } | null;
    error: AccountDeletionOperationError | null;
  }>;
  revokeRefreshSessions(token: string): Promise<{
    error: AccountDeletionOperationError | null;
  }>;
  deleteUser(userID: string): Promise<{
    error: AccountDeletionOperationError | null;
  }>;
}

interface FailureLog {
  event: "account-deletion-failed";
  request_id: string;
  stage:
    | "configuration"
    | "authentication"
    | "refresh_session_revocation"
    | "user_deletion";
  error: string;
}

type FailureLogger = (entry: FailureLog) => void;

const accessTokenBoundary = {
  access_tokens_remain_valid_until_expiry: true,
};

const jsonHeaders = {
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
};

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
  headers: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...headers },
  });
}

function failureResponse(
  status: number,
  code: string,
  message: string,
  stage: FailureLog["stage"],
  requestID: string,
  extra: Record<string, unknown> = {},
) {
  return jsonResponse(status, {
    code,
    message,
    stage,
    request_id: requestID,
    deleted: false,
    ...extra,
  });
}

function thrownErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function createDeleteAccountHandler(
  gateway: AccountDeletionGateway | null,
  logFailure: FailureLogger = (entry) => console.error(JSON.stringify(entry)),
) {
  return async (request: Request): Promise<Response> => {
    const requestID = crypto.randomUUID();

    if (request.method !== "POST") {
      return jsonResponse(
        405,
        {
          code: "method_not_allowed",
          message: "Method not allowed",
          request_id: requestID,
          deleted: false,
        },
        { Allow: "POST" },
      );
    }

    if (!gateway) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "configuration",
        error: "Required Supabase environment variables are missing",
      });
      return failureResponse(
        500,
        "configuration_error",
        "Account deletion is unavailable",
        "configuration",
        requestID,
      );
    }

    const authorization = request.headers.get("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? "";
    if (!token) {
      return failureResponse(
        401,
        "missing_bearer_token",
        "Authentication is required",
        "authentication",
        requestID,
      );
    }

    let userResult: Awaited<ReturnType<AccountDeletionGateway["getUser"]>>;
    try {
      userResult = await gateway.getUser(token);
    } catch (error) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "authentication",
        error: thrownErrorMessage(error),
      });
      return failureResponse(
        502,
        "authentication_lookup_failed",
        "Authentication could not be verified",
        "authentication",
        requestID,
      );
    }

    const { user, error: userError } = userResult;
    if (userError || !user) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "authentication",
        error: userError?.message ?? "Authenticated user is missing",
      });
      return failureResponse(
        401,
        "invalid_bearer_token",
        "Authentication is invalid or expired",
        "authentication",
        requestID,
      );
    }

    let refreshSessionRevocationResult: Awaited<
      ReturnType<AccountDeletionGateway["revokeRefreshSessions"]>
    >;
    try {
      refreshSessionRevocationResult = await gateway.revokeRefreshSessions(
        token,
      );
    } catch (error) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "refresh_session_revocation",
        error: thrownErrorMessage(error),
      });
      return failureResponse(
        502,
        "refresh_session_revocation_failed",
        "Refresh sessions could not be revoked",
        "refresh_session_revocation",
        requestID,
        {
          refresh_sessions_revoked: false,
          deleted: false,
          ...accessTokenBoundary,
        },
      );
    }

    const { error: revokeError } = refreshSessionRevocationResult;
    if (revokeError) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "refresh_session_revocation",
        error: revokeError.message,
      });
      return failureResponse(
        502,
        "refresh_session_revocation_failed",
        "Refresh sessions could not be revoked",
        "refresh_session_revocation",
        requestID,
        {
          refresh_sessions_revoked: false,
          deleted: false,
          ...accessTokenBoundary,
        },
      );
    }

    let deleteResult: Awaited<
      ReturnType<AccountDeletionGateway["deleteUser"]>
    >;
    try {
      deleteResult = await gateway.deleteUser(user.id);
    } catch (error) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "user_deletion",
        error: thrownErrorMessage(error),
      });
      return failureResponse(
        502,
        "account_deletion_failed",
        "The account deletion outcome could not be confirmed",
        "user_deletion",
        requestID,
        {
          refresh_sessions_revoked: true,
          deleted: null,
          ...accessTokenBoundary,
        },
      );
    }

    const { error: deleteError } = deleteResult;
    if (deleteError) {
      logFailure({
        event: "account-deletion-failed",
        request_id: requestID,
        stage: "user_deletion",
        error: deleteError.message,
      });
      return failureResponse(
        500,
        "account_deletion_failed",
        "The account could not be deleted",
        "user_deletion",
        requestID,
        {
          refresh_sessions_revoked: true,
          deleted: false,
          ...accessTokenBoundary,
        },
      );
    }

    return jsonResponse(200, {
      deleted: true,
      refresh_sessions_revoked: true,
      ...accessTokenBoundary,
      request_id: requestID,
    });
  };
}
