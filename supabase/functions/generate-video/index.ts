import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * Supabase Edge Function: generate-video
 *
 * Wire this to your AI video model (Runway, Pika, Replicate, etc.).
 * This stub returns a placeholder — replace `generateWithAI` with your provider.
 */
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { prompt, video_id, user_id } = await req.json();

  if (!prompt || !video_id || !user_id) {
    return new Response(JSON.stringify({ error: "Missing fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // TODO: Replace with your AI video generation API call
  const result = await generateWithAI(prompt);

  const storagePath = `${user_id}/${video_id}.mp4`;
  // TODO: Upload result.videoBytes to storage bucket `generated-videos`

  const { data: urlData } = supabase.storage
    .from("generated-videos")
    .getPublicUrl(storagePath);

  return new Response(
    JSON.stringify({
      video_url: urlData.publicUrl,
      thumbnail_url: result.thumbnailUrl,
      storage_path: storagePath,
      duration_seconds: result.durationSeconds,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});

async function generateWithAI(prompt: string) {
  // Integrate your model here
  return {
    thumbnailUrl: `https://picsum.photos/seed/${encodeURIComponent(prompt)}/400/700`,
    durationSeconds: 15,
  };
}
