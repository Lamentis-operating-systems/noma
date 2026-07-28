import {
  type AccountDeletionGateway,
  createDeleteAccountHandler,
} from "./handler.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function responseJSON(response: Response) {
  return await response.json() as Record<string, unknown>;
}

function resolved<T>(value: T): Promise<T> {
  return Promise.resolve(value);
}

function makeGateway(
  overrides: Partial<AccountDeletionGateway> = {},
): AccountDeletionGateway {
  return {
    getUser: () => resolved({ user: { id: "user-1" }, error: null }),
    revokeRefreshSessions: () => resolved({ error: null }),
    deleteUser: () => resolved({ error: null }),
    ...overrides,
  };
}

Deno.test("requires POST", async () => {
  const response = await createDeleteAccountHandler(makeGateway())(
    new Request("https://example.test", { method: "GET" }),
  );

  assert(response.status === 405, "expected 405");
  assert(
    response.headers.get("Allow") === "POST",
    "expected POST Allow header",
  );
  const body = await responseJSON(response);
  assert(body.deleted === false, "method rejection must report not deleted");
});

Deno.test("rejects a missing bearer token before gateway calls", async () => {
  let didLookUpUser = false;
  const gateway = makeGateway({
    getUser: () => {
      didLookUpUser = true;
      return resolved({ user: null, error: null });
    },
  });

  const response = await createDeleteAccountHandler(gateway)(
    new Request("https://example.test", { method: "POST" }),
  );
  const body = await responseJSON(response);

  assert(response.status === 401, "expected 401");
  assert(body.code === "missing_bearer_token", "expected missing-token code");
  assert(
    body.deleted === false,
    "failure before deletion must report not deleted",
  );
  assert(!didLookUpUser, "gateway must not be called without a token");
});

Deno.test("does not delete when refresh-session revocation fails", async () => {
  let didDelete = false;
  const gateway = makeGateway({
    revokeRefreshSessions: () =>
      resolved({ error: { message: "revoke failed" } }),
    deleteUser: () => {
      didDelete = true;
      return resolved({ error: null });
    },
  });

  const response = await createDeleteAccountHandler(gateway, () => {})(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 502, "expected 502");
  assert(
    body.stage === "refresh_session_revocation",
    "expected refresh-session revocation stage",
  );
  assert(
    body.refresh_sessions_revoked === false,
    "refresh-session revocation must be reported as incomplete",
  );
  assert(
    body.access_tokens_remain_valid_until_expiry === true,
    "access-token lifetime boundary must be explicit",
  );
  assert(body.deleted === false, "deletion must be reported as incomplete");
  assert(!didDelete, "user deletion must not run after revocation failure");
});

Deno.test("reports user deletion failure after successful revocation", async () => {
  const response = await createDeleteAccountHandler(
    makeGateway({
      deleteUser: () => resolved({ error: { message: "delete failed" } }),
    }),
    () => {},
  )(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 500, "expected 500");
  assert(body.stage === "user_deletion", "expected deletion stage");
  assert(
    body.refresh_sessions_revoked === true,
    "refresh-session revocation must be reported as complete",
  );
  assert(
    body.access_tokens_remain_valid_until_expiry === true,
    "access-token lifetime boundary must be explicit",
  );
  assert(body.deleted === false, "deletion must be reported as incomplete");
});

Deno.test("returns explicit completion only after revoke and delete", async () => {
  const calls: string[] = [];
  const gateway = makeGateway({
    getUser: () => {
      calls.push("authenticate");
      return resolved({ user: { id: "user-1" }, error: null });
    },
    revokeRefreshSessions: () => {
      calls.push("revoke");
      return resolved({ error: null });
    },
    deleteUser: (userID) => {
      calls.push(`delete:${userID}`);
      return resolved({ error: null });
    },
  });

  const response = await createDeleteAccountHandler(gateway)(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 200, "expected 200");
  assert(
    body.refresh_sessions_revoked === true,
    "expected revoked refresh sessions",
  );
  assert(
    body.access_tokens_remain_valid_until_expiry === true,
    "access-token lifetime boundary must be explicit",
  );
  assert(body.deleted === true, "expected deleted account");
  assert(
    calls.join(",") === "authenticate,revoke,delete:user-1",
    "unexpected operation order",
  );
});

Deno.test("maps a thrown authentication lookup to a structured response", async () => {
  const response = await createDeleteAccountHandler(
    makeGateway({
      getUser: () => Promise.reject(new Error("auth network failed")),
    }),
    () => {},
  )(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 502, "expected 502");
  assert(body.stage === "authentication", "expected authentication stage");
  assert(
    body.code === "authentication_lookup_failed",
    "expected authentication lookup code",
  );
  assert(typeof body.request_id === "string", "expected request id");
  assert(
    body.deleted === false,
    "authentication failure must report not deleted",
  );
});

Deno.test("maps thrown refresh-session revocation to a structured response", async () => {
  const response = await createDeleteAccountHandler(
    makeGateway({
      revokeRefreshSessions: () =>
        Promise.reject(new Error("revocation network failed")),
    }),
    () => {},
  )(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 502, "expected 502");
  assert(
    body.stage === "refresh_session_revocation",
    "expected refresh-session revocation stage",
  );
  assert(
    body.refresh_sessions_revoked === false,
    "expected incomplete refresh-session revocation",
  );
  assert(typeof body.request_id === "string", "expected request id");
  assert(body.deleted === false, "revocation failure must report not deleted");
});

Deno.test("maps thrown user deletion to a structured response", async () => {
  const response = await createDeleteAccountHandler(
    makeGateway({
      deleteUser: () => Promise.reject(new Error("deletion network failed")),
    }),
    () => {},
  )(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer access-token" },
    }),
  );
  const body = await responseJSON(response);

  assert(response.status === 502, "expected 502");
  assert(body.stage === "user_deletion", "expected user-deletion stage");
  assert(
    body.refresh_sessions_revoked === true,
    "expected completed refresh-session revocation",
  );
  assert(
    body.deleted === null,
    "a thrown delete call must report an unknown remote outcome",
  );
  assert(typeof body.request_id === "string", "expected request id");
});
