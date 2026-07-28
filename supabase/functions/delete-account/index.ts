import { createClient } from "@supabase/supabase-js";

import {
  type AccountDeletionGateway,
  createDeleteAccountHandler,
} from "./handler.ts";

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

let gateway: AccountDeletionGateway | null = null;

if (supabaseURL && serviceRoleKey) {
  const supabase = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  gateway = {
    async getUser(token) {
      const { data, error } = await supabase.auth.getUser(token);
      return {
        user: data.user ? { id: data.user.id } : null,
        error,
      };
    },
    async revokeRefreshSessions(token) {
      const { error } = await supabase.auth.admin.signOut(token, "global");
      return { error };
    },
    async deleteUser(userID) {
      const { error } = await supabase.auth.admin.deleteUser(userID);
      return { error };
    },
  };
}

Deno.serve(createDeleteAccountHandler(gateway));
