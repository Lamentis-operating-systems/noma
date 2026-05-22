import { createClient } from "jsr:@supabase/supabase-js@2";

const jsonHeaders = {
  "Content-Type": "application/json",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return jsonResponse(500, { error: "Supabase deletion function is not configured" });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    return jsonResponse(401, { error: "Missing bearer token" });
  }

  const supabase = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "Invalid bearer token" });
  }

  await supabase.auth.admin.signOut(token, "global");

  const { error: deleteError } = await supabase.auth.admin.deleteUser(userData.user.id);
  if (deleteError) {
    return jsonResponse(500, { error: deleteError.message });
  }

  return jsonResponse(200, { deleted: true });
});
