require("dotenv").config();
const { createClient } = require("@supabase/supabase-js");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
);

async function checkProfiles() {
  const d30 = new Date();
  d30.setDate(d30.getDate() - 30);

  const { data, error } = await supabase
    .from("profiles")
    .select(
      "id, full_name, is_active, receive_bottles, bottles_received_today, last_active, gender, birth_year",
    )
    .limit(10);

  if (error) console.error(error);
  else {
    console.log(
      "ALL PROFILES (sample limit 10):",
      JSON.stringify(data, null, 2),
    );

    // Test the exact match filter
    const { data: mData, error: mError } = await supabase
      .from("profiles")
      .select(
        "id, full_name, is_active, receive_bottles, bottles_received_today, last_active",
      )
      .eq("is_active", true)
      .eq("receive_bottles", true)
      .lt("bottles_received_today", 5)
      .gte("last_active", d30.toISOString());

    console.log("MATCHING PROFILES:", mData ? mData.length : mError);
  }
}

checkProfiles();
