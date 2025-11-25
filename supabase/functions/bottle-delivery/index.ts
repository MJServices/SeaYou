// Supabase Edge Function: Bottle Delivery
// Deploy this to Supabase Edge Functions
// Run: supabase functions deploy bottle-delivery

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('Starting bottle delivery check...')

    // 1. Get bottles ready for delivery
    const { data: pendingBottles, error: fetchError } = await supabaseClient
      .from('bottle_delivery_queue')
      .select('*')
      .eq('delivered', false)
      .lte('scheduled_delivery_at', new Date().toISOString())

    if (fetchError) {
      throw fetchError
    }

    console.log(`Found ${pendingBottles?.length || 0} bottles ready for delivery`)

    let deliveredCount = 0
    let errorCount = 0

    // 2. Deliver each bottle
    for (const queueItem of pendingBottles || []) {
      try {
        const bottleId = queueItem.sent_bottle_id
        const recipientId = queueItem.recipient_id

        // Update sent bottle status to 'delivered'
        const { error: updateSentError } = await supabaseClient
          .from('sent_bottles')
          .update({
            status: 'delivered',
            delivered_at: new Date().toISOString(),
          })
          .eq('id', bottleId)

        if (updateSentError) {
          console.error(`Error updating sent bottle ${bottleId}:`, updateSentError)
          errorCount++
          continue
        }

        // Mark delivery queue item as delivered
        const { error: updateQueueError } = await supabaseClient
          .from('bottle_delivery_queue')
          .update({
            delivered: true,
            delivered_at: new Date().toISOString(),
          })
          .eq('id', queueItem.id)

        if (updateQueueError) {
          console.error(`Error updating queue item ${queueItem.id}:`, updateQueueError)
          errorCount++
          continue
        }

        // Increment recipient's bottles_received_today counter
        const { error: incrementError } = await supabaseClient
          .rpc('increment_bottles_received', { user_id: recipientId })

        if (incrementError) {
          console.error(`Error incrementing counter for ${recipientId}:`, incrementError)
          // Don't fail delivery if counter increment fails
        }

        console.log(`✓ Delivered bottle ${bottleId} to ${recipientId}`)
        deliveredCount++

      } catch (error) {
        console.error('Error delivering bottle:', error)
        errorCount++
      }
    }

    // 3. Return summary
    const response = {
      success: true,
      message: `Delivery check complete`,
      stats: {
        checked: pendingBottles?.length || 0,
        delivered: deliveredCount,
        errors: errorCount,
      },
      timestamp: new Date().toISOString(),
    }

    console.log('Delivery summary:', response)

    return new Response(
      JSON.stringify(response),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Fatal error in bottle delivery:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
