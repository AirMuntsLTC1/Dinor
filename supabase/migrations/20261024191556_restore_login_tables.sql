-- Dinor: restore the tables that request-email-code needs
CREATE TABLE IF NOT EXISTS public.google_oauth_credentials (
  id text PRIMARY KEY,
  refresh_token text NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.google_oauth_credentials ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Only service role can access credentials" ON public.google_oauth_credentials;
CREATE POLICY "Only service role can access credentials"
ON public.google_oauth_credentials
USING (false) WITH CHECK (false);

CREATE TABLE IF NOT EXISTS public.email_code_rate_limits (
  email text PRIMARY KEY,
  last_sent_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  window_started_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  request_count integer DEFAULT 1 NOT NULL
);
ALTER TABLE public.email_code_rate_limits ENABLE ROW LEVEL SECURITY;
