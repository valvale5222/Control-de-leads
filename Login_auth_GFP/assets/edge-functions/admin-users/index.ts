// supabase/functions/admin-users/index.ts
//
// Operaciones administrativas que requieren la service role key y por eso
// NO pueden ejecutarse en el navegador:
//   - create      : crear usuario con contraseña (auth.admin.createUser)
//   - set_active  : activar / desactivar (perfil + bloqueo de login en Supabase Auth)
//
// Cambiar rol o editar nombre NO pasa por aquí: el frontend lo hace directo con RLS
// (supabase.rpc('set_user_role', ...) y update de public.users).
//
// Seguridad:
//   1. Exige el JWT del usuario que llama (header Authorization).
//   2. Verifica is_admin() con un cliente que respeta RLS.
//   3. Solo entonces usa la service role, que Supabase inyecta como variable de entorno
//      de la función. Nunca se envía ni se devuelve al cliente.
//
// Deploy:  supabase functions deploy admin-users
// Llamada: supabase.functions.invoke('admin-users', { body: { action: 'create', ... } })

import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "*";
const cors = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ROLE_IDS = [1, 2, 3]; // Admin, Editor, Visualizador
const BAN_FOREVER = "876000h"; // ~100 años

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Método no permitido" });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json(401, { error: "No autenticado" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Cliente con la identidad de quien llama: respeta RLS y las guardas de la BD
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await caller.auth.getUser();
  if (userErr || !userData?.user) return json(401, { error: "Sesión inválida" });
  const callerId = userData.user.id;

  const { data: isAdmin, error: roleErr } = await caller.rpc("is_admin");
  if (roleErr || isAdmin !== true) return json(403, { error: "Solo un Admin puede realizar esta acción" });

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Cuerpo JSON inválido" });
  }

  try {
    switch (body.action) {
      case "create": {
        const email = String(body.email ?? "").trim().toLowerCase();
        const password = String(body.password ?? "");
        const name = String(body.name ?? "").trim();
        const last_name = String(body.last_name ?? "").trim();
        const role_id = Number(body.role_id ?? 3);
        const is_active = body.is_active !== false;

        if (!EMAIL_RE.test(email)) return json(400, { error: "Correo inválido" });
        if (password.length < 8) return json(400, { error: "La contraseña debe tener al menos 8 caracteres" });
        if (!name) return json(400, { error: "El nombre es obligatorio" });
        if (!ROLE_IDS.includes(role_id)) return json(400, { error: "Rol inválido" });

        // El trigger on_auth_user_created crea public.users + rol Visualizador
        const { data: created, error: createErr } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { name, last_name },
        });
        if (createErr || !created?.user) {
          return json(400, { error: createErr?.message ?? "No se pudo crear el usuario" });
        }
        const newId = created.user.id;

        // Rol y estado se aplican con la identidad del Admin (RLS + guardas activas)
        const { error: roleSetErr } = await caller.rpc("set_user_role", {
          p_user_id: newId,
          p_role_id: role_id,
        });
        if (roleSetErr) {
          await admin.auth.admin.deleteUser(newId); // revertir
          return json(400, { error: roleSetErr.message });
        }

        if (!is_active) {
          await caller.from("users").update({ is_active: false }).eq("id", newId);
          await admin.auth.admin.updateUserById(newId, { ban_duration: BAN_FOREVER });
        }

        return json(200, { id: newId, email });
      }

      case "set_active": {
        const user_id = String(body.user_id ?? "");
        const is_active = body.is_active === true;
        if (!user_id) return json(400, { error: "user_id es obligatorio" });
        if (user_id === callerId && !is_active) {
          return json(400, { error: "No puedes desactivar tu propia cuenta" });
        }

        // Primero el perfil (aplica la guarda de "último Admin activo")
        const { error: updErr } = await caller
          .from("users")
          .update({ is_active })
          .eq("id", user_id);
        if (updErr) return json(400, { error: updErr.message });

        // Luego bloquear / desbloquear el inicio de sesión en Supabase Auth
        const { error: banErr } = await admin.auth.admin.updateUserById(user_id, {
          ban_duration: is_active ? "none" : BAN_FOREVER,
        });
        if (banErr) return json(500, { error: banErr.message });

        return json(200, { id: user_id, is_active });
      }

      default:
        return json(400, { error: "Acción no soportada" });
    }
  } catch (e) {
    console.error("admin-users error:", e instanceof Error ? e.message : "desconocido");
    return json(500, { error: "Error interno" });
  }
});
