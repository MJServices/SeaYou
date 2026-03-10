const { createClient } = require("@supabase/supabase-js");
const fs = require("fs");
require("dotenv").config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function testScrolls() {
  console.log("Fetching test profile...");
  const { data, error } = await supabase
    .from("profiles")
    .select(
      "id, email, scrolls_count, daily_free_scrolls, last_scroll_refreshed_date",
    )
    .limit(1);

  if (error) {
    console.error(error);
    return;
  }

  const user = data[0];
  console.log("Current State:", user);

  console.log("Attempting to use_scroll via RPC...");
  const { data: rpcData, error: rpcError } = await supabase.rpc("use_scroll", {
    user_id: user.id,
  });

  if (rpcError) {
    console.error("RPC Error:", rpcError);
  } else {
    console.log("RPC Success. Scroll deducted?", rpcData);
  }

  const { data: afterData } = await supabase
    .from("profiles")
    .select("scrolls_count, daily_free_scrolls")
    .eq("id", user.id)
    .single();

  console.log("State After RPC:", afterData);
}

testScrolls();
