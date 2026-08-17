
-- Enable pg_cron and pg_net extensions
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Add additional profile fields
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS telephone_secondaire text,
  ADD COLUMN IF NOT EXISTS adresse_mail_secondaire text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS type_piece_identite text,
  ADD COLUMN IF NOT EXISTS numero_piece_identite text,
  ADD COLUMN IF NOT EXISTS piece_identite_url text,
  ADD COLUMN IF NOT EXISTS contact_urgence_nom text,
  ADD COLUMN IF NOT EXISTS contact_urgence_prenom text,
  ADD COLUMN IF NOT EXISTS contact_urgence_telephone1 text,
  ADD COLUMN IF NOT EXISTS contact_urgence_telephone2 text,
  ADD COLUMN IF NOT EXISTS contact_urgence_photo_url text;

-- Schedule CRON job for payment reminders at 8am daily (UTC+0, Abidjan is UTC+0)
SELECT cron.schedule(
  'payment-reminders-daily',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url := 'https://rfzfsmpsuempafhkqhra.supabase.co/functions/v1/payment-reminders',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmemZzbXBzdWVtcGFmaGtxaHJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDE5NjcsImV4cCI6MjA4NjcxNzk2N30.v3sQGr7QHdDqkg4EVHf8l702KKbcOZ8XiP9ALisJFl4"}'::jsonb,
    body := concat('{"time": "', now(), '"}')::jsonb
  ) AS request_id;
  $$
);
