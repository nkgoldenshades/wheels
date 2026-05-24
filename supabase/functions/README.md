# Supabase Edge Functions

This directory contains Deno-based Edge Functions for Supabase.

## VS Code Errors - IGNORE THEM!

**You may see TypeScript errors like:**
- ❌ "Cannot find module 'https://deno.land/std@0.168.0/http/server.ts'"
- ❌ "Cannot find module 'https://esm.sh/@supabase/supabase-js@2'"
- ❌ "Cannot find name 'Deno'"

**These errors are NORMAL and can be safely ignored!**

### Why?

- These functions run in **Deno runtime**, not Node.js
- Deno uses URL imports (https://...) which VS Code's TypeScript doesn't understand
- The code works perfectly when deployed to Supabase

### How to Fix (Optional)

If the red squiggles bother you:

1. **Install Deno Extension**:
   - Press `Ctrl+Shift+X`
   - Search: "Deno"
   - Install "Deno" by Deno Land

2. **Reload VS Code**:
   - Press `Ctrl+Shift+P`
   - Type: "Developer: Reload Window"

3. **Enable Deno**:
   - Open any `.ts` file in this folder
   - Press `Ctrl+Shift+P`
   - Type: "Deno: Initialize Workspace Configuration"
   - Select "Enable"

### Or Just Ignore

The errors don't affect functionality. Your functions will work perfectly when deployed!

## Deploying Functions

```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy ai-search-posts
```

## Testing Locally

```bash
# Serve functions locally
supabase functions serve

# Test with curl
curl -X POST http://localhost:54321/functions/v1/ai-search-posts \
  -H "Content-Type: application/json" \
  -d '{"query": "cheap ride from Chennai to Bangalore"}'
```

## Available Functions

- **ai-search-posts**: Natural language search for posts/rides
- More functions coming soon...
