
-- Drop unused tables from the old login system
drop table if exists public.otp_codes cascade;
drop table if exists public.google_tokens cascade;
drop table if exists public.google_oauth_credentials cascade;
drop table if exists public.email_code_rate_limits cascade;

-- Ensure the chat_media bucket is public (just in case)
update storage.buckets set public = true where id = 'chat_media';
