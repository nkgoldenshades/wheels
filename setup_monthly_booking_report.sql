-- Monthly Booking Report Email System
-- Sends a monthly summary of all bookings to admins every 1st of the month

-- ============================================
-- STEP 1: Enable pg_cron extension (run once)
-- ============================================
-- Note: pg_cron is available on Supabase paid plans
-- For free tier, use Option 2 (Edge Function + GitHub Actions)

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================
-- STEP 2: Create function to generate monthly report
-- ============================================

CREATE OR REPLACE FUNCTION send_monthly_booking_report()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  report_data jsonb;
  email_body text;
  admin_emails text[] := ARRAY['admin@quickohunt.com']; -- Replace with your admin emails
  month_name text;
  total_bookings int;
  completed_bookings int;
  cancelled_bookings int;
  total_revenue numeric;
BEGIN
  -- Get month name for report
  month_name := to_char(current_date - interval '1 month', 'Month YYYY');
  
  -- Generate report data for previous month
  SELECT 
    count(*) as total,
    count(*) FILTER (WHERE status = 'completed') as completed,
    count(*) FILTER (WHERE status IN ('cancelled', 'rejected', 'expired')) as cancelled,
    sum(total_price) FILTER (WHERE status = 'completed') as revenue
  INTO 
    total_bookings,
    completed_bookings,
    cancelled_bookings,
    total_revenue
  FROM bookings
  WHERE created_at >= date_trunc('month', current_date - interval '1 month')
    AND created_at < date_trunc('month', current_date);

  -- Build email body
  email_body := format(
    E'Monthly Booking Report - %s\n\n' ||
    E'📊 Summary:\n' ||
    E'━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' ||
    E'Total Bookings: %s\n' ||
    E'✅ Completed: %s\n' ||
    E'❌ Cancelled: %s\n' ||
    E'💰 Revenue: ₹%s\n\n' ||
    E'View full details in your dashboard.',
    month_name,
    total_bookings,
    completed_bookings,
    cancelled_bookings,
    coalesce(total_revenue, 0)
  );

  -- Send email using Supabase Edge Function or external service
  -- Option A: Call Supabase Edge Function
  PERFORM net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := jsonb_build_object(
      'to', admin_emails,
      'subject', 'Monthly Booking Report - ' || month_name,
      'text', email_body
    )
  );

  RAISE NOTICE 'Monthly report sent for %', month_name;
END;
$$;

-- ============================================
-- STEP 3: Schedule the job to run monthly
-- ============================================

-- Run on 1st of every month at 9:00 AM
SELECT cron.schedule(
  'monthly-booking-report',           -- Job name
  '0 9 1 * *',                        -- Cron expression: 9 AM on 1st of month
  'SELECT send_monthly_booking_report();'
);

-- ============================================
-- STEP 4: View scheduled jobs
-- ============================================

SELECT * FROM cron.job;

-- ============================================
-- STEP 5: Test the function manually
-- ============================================

-- Uncomment to test:
-- SELECT send_monthly_booking_report();

-- ============================================
-- STEP 6: Unschedule job (if needed)
-- ============================================

-- Uncomment to remove:
-- SELECT cron.unschedule('monthly-booking-report');

-- ============================================
-- ALTERNATIVE: Weekly report (every Monday)
-- ============================================

-- Uncomment for weekly reports instead:
-- SELECT cron.schedule(
--   'weekly-booking-report',
--   '0 9 * * 1',  -- Every Monday at 9 AM
--   'SELECT send_monthly_booking_report();'
-- );
