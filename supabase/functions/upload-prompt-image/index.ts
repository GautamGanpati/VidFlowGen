import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const BUCKET = "prompt-images";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: { user_id?: string; image_base64?: string; content_type?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { user_id, image_base64, content_type } = body;
  if (!user_id || !image_base64) {
    return new Response(
      JSON.stringify({ error: "Missing user_id or image_base64" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: buckets, error: listError } = await supabase.storage.listBuckets();
  if (listError) {
    return new Response(JSON.stringify({ error: listError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!buckets?.some((bucket) => bucket.id === BUCKET)) {
    const { error: createError } = await supabase.storage.createBucket(BUCKET, {
      public: true,
      fileSizeLimit: 10 * 1024 * 1024,
      allowedMimeTypes: ["image/jpeg", "image/png", "image/webp"],
    });
    if (createError && !createError.message.toLowerCase().includes("already")) {
      return new Response(JSON.stringify({ error: createError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const mime = content_type ?? "image/jpeg";
  const ext = mime.includes("png")
    ? "png"
    : mime.includes("webp")
    ? "webp"
    : "jpg";
  const path = `${user_id}/${Date.now()}.${ext}`;

  const binary = Uint8Array.from(atob(image_base64), (char) => char.charCodeAt(0));

  const { error: uploadError } = await supabase.storage.from(BUCKET).upload(
    path,
    binary,
    { contentType: mime, upsert: true },
  );

  if (uploadError) {
    return new Response(JSON.stringify({ error: uploadError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(path);

  return new Response(
    JSON.stringify({ public_url: urlData.publicUrl }),
    { headers: { "Content-Type": "application/json" } },
  );
});
