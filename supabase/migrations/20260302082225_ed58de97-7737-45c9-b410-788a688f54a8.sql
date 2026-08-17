
-- Schedule CRON job for payment reminders at 8am daily
SELECT cron.schedule(
  'daily-payment-reminders',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url:='https://rfzfsmpsuempafhkqhra.supabase.co/functions/v1/payment-reminders',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmemZzbXBzdWVtcGFmaGtxaHJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDE5NjcsImV4cCI6MjA4NjcxNzk2N30.v3sQGr7QHdDqkg4EVHf8l702KKbcOZ8XiP9ALisJFl4"}'::jsonb,
    body:='{"time": "scheduled"}'::jsonb
  ) AS request_id;
  $$
);
