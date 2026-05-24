/**
 * AI Search Posts - Supabase Edge Function
 * 
 * NOTE: VS Code may show import errors for Deno modules.
 * This is normal - the code runs perfectly in Deno/Supabase runtime.
 * 
 * To fix VS Code errors:
 * 1. Install "Deno" extension from VS Code marketplace
 * 2. Reload VS Code window
 * 3. Or simply ignore - the code works fine when deployed
 */

// deno-lint-ignore-file no-explicit-any
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
// @ts-ignore - Deno module
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Deno global type declaration for VS Code
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SearchIntent {
  service_type?: string
  slot_type?: string
  pickup_mode?: string
  post_mode?: string
  min_price?: number
  max_price?: number
  start_date?: string
  end_date?: string
  locations: string[]
  passengers?: number
}

interface Post {
  id: string
  service_type: string
  slot_type: string
  from_location?: string
  to_location?: string
  base_location?: string
  price: number
  start_time: string
  end_time: string
  capacity: number
  is_active: boolean
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { query } = await req.json()

    if (!query || typeof query !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Query is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('🤖 AI Search query:', query)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Parse natural language query into structured intent
    const intent = await parseSearchIntent(query)
    console.log('🧠 Parsed intent:', intent)

    // Build database query based on intent
    let dbQuery = supabase
      .from('posts')
      .select('id, service_type, slot_type, from_location, to_location, base_location, price, start_time, end_time, capacity, is_active')
      .eq('is_active', true)
      .gt('end_time', new Date().toISOString())

    // Apply filters based on intent
    if (intent.service_type) {
      dbQuery = dbQuery.eq('service_type', intent.service_type)
    }

    if (intent.slot_type) {
      dbQuery = dbQuery.eq('slot_type', intent.slot_type)
    }

    if (intent.min_price !== undefined) {
      dbQuery = dbQuery.gte('price', intent.min_price)
    }

    if (intent.max_price !== undefined) {
      dbQuery = dbQuery.lte('price', intent.max_price)
    }

    if (intent.start_date) {
      dbQuery = dbQuery.gte('start_time', intent.start_date)
    }

    if (intent.end_date) {
      dbQuery = dbQuery.lte('end_time', intent.end_date)
    }

    // Execute query
    const { data: posts, error } = await dbQuery.order('created_at', { ascending: false }).limit(50)

    if (error) {
      throw error
    }

    // Filter by location if specified
    let matchedPosts = posts || []
    if (intent.locations.length > 0) {
      matchedPosts = matchedPosts.filter((post: Post) => {
        const locations = [
          post.from_location,
          post.to_location,
          post.base_location,
        ].filter(Boolean).join(' ').toLowerCase()

        return intent.locations.some(loc => 
          locations.includes(loc.toLowerCase())
        )
      })
    }

    // Generate suggestions
    const suggestions = generateSuggestions(intent, matchedPosts.length)

    return new Response(
      JSON.stringify({
        intent,
        suggestions,
        matched_post_ids: matchedPosts.map((p: Post) => p.id),
        total_matches: matchedPosts.length,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: unknown) {
    console.error('❌ AI search error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Parse natural language query into structured search intent
 */
async function parseSearchIntent(query: string): Promise<SearchIntent> {
  const lowerQuery = query.toLowerCase()
  const intent: SearchIntent = { locations: [] }

  // Service type detection
  if (lowerQuery.match(/passenger|ride|taxi|cab|car|transport/)) {
    intent.service_type = 'passenger'
  } else if (lowerQuery.match(/parcel|delivery|package|courier|cargo|freight/)) {
    intent.service_type = 'parcel'
  } else if (lowerQuery.match(/lease|rent|rental|hire/)) {
    intent.service_type = 'lease'
  }

  // Route type detection
  if (lowerQuery.match(/from .+ to .+/)) {
    intent.slot_type = 'fromTo'
    // Extract locations
    const fromToMatch = lowerQuery.match(/from\s+([a-z\s]+)\s+to\s+([a-z\s]+)/i)
    if (fromToMatch) {
      intent.locations.push(fromToMatch[1].trim(), fromToMatch[2].trim())
    }
  } else if (lowerQuery.match(/nearby|around|near|within/)) {
    intent.slot_type = 'fromRange'
    // Extract base location
    const nearMatch = lowerQuery.match(/(?:near|around|in)\s+([a-z\s]+)/i)
    if (nearMatch) {
      intent.locations.push(nearMatch[1].trim())
    }
  }

  // Price detection
  const priceMatch = lowerQuery.match(/(?:under|below|less than|max|maximum)\s+(\d+)/)
  if (priceMatch) {
    intent.max_price = parseInt(priceMatch[1])
  }

  const minPriceMatch = lowerQuery.match(/(?:over|above|more than|min|minimum)\s+(\d+)/)
  if (minPriceMatch) {
    intent.min_price = parseInt(minPriceMatch[1])
  }

  // Date detection
  if (lowerQuery.match(/today/)) {
    const today = new Date()
    intent.start_date = today.toISOString()
    intent.end_date = new Date(today.getTime() + 24 * 60 * 60 * 1000).toISOString()
  } else if (lowerQuery.match(/tomorrow/)) {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    intent.start_date = tomorrow.toISOString()
    intent.end_date = new Date(tomorrow.getTime() + 24 * 60 * 60 * 1000).toISOString()
  } else if (lowerQuery.match(/this week/)) {
    const today = new Date()
    const endOfWeek = new Date(today)
    endOfWeek.setDate(today.getDate() + (7 - today.getDay()))
    intent.start_date = today.toISOString()
    intent.end_date = endOfWeek.toISOString()
  } else if (lowerQuery.match(/next week/)) {
    const today = new Date()
    const nextWeekStart = new Date(today)
    nextWeekStart.setDate(today.getDate() + (7 - today.getDay()) + 1)
    const nextWeekEnd = new Date(nextWeekStart)
    nextWeekEnd.setDate(nextWeekStart.getDate() + 7)
    intent.start_date = nextWeekStart.toISOString()
    intent.end_date = nextWeekEnd.toISOString()
  }

  // Passenger count detection
  const passengerMatch = lowerQuery.match(/(\d+)\s+(?:passenger|person|people|seat)/i)
  if (passengerMatch) {
    intent.passengers = parseInt(passengerMatch[1])
  }

  // Extract city names (common Indian cities)
  const cities = [
    'mumbai', 'delhi', 'bangalore', 'hyderabad', 'chennai', 'kolkata', 'pune', 'ahmedabad',
    'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'bhopal', 'visakhapatnam', 'patna',
    'vadodara', 'ghaziabad', 'ludhiana', 'agra', 'nashik', 'faridabad', 'meerut', 'rajkot',
    'varanasi', 'srinagar', 'aurangabad', 'dhanbad', 'amritsar', 'allahabad', 'ranchi', 'gwalior',
  ]

  cities.forEach(city => {
    if (lowerQuery.includes(city) && !intent.locations.includes(city)) {
      intent.locations.push(city)
    }
  })

  return intent
}

/**
 * Generate helpful suggestions based on query and results
 */
function generateSuggestions(intent: SearchIntent, matchCount: number): string[] {
  const suggestions: string[] = []

  if (matchCount === 0) {
    suggestions.push('No matches found. Try broadening your search.')
    
    if (intent.max_price) {
      suggestions.push(`Try increasing your budget above ${intent.max_price}`)
    }
    
    if (intent.locations.length > 0) {
      suggestions.push('Try searching in nearby cities')
    }
    
    if (intent.service_type) {
      suggestions.push('Try a different service type')
    }
  } else if (matchCount < 5) {
    suggestions.push(`Found ${matchCount} matches. Try broadening your search for more options.`)
  } else {
    suggestions.push(`Found ${matchCount} matches!`)
    
    if (intent.service_type) {
      suggestions.push(`Showing ${intent.service_type} services`)
    }
    
    if (intent.locations.length > 0) {
      suggestions.push(`Filtered by: ${intent.locations.join(', ')}`)
    }
  }

  return suggestions
}
