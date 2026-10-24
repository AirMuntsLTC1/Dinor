
-- Re-create the table to store the Gmail Refresh Token
create table if not exists public.google_oauth_credentials (
  id text primary key,
  refresh_token text not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.google_oauth_credentials enable row level security;

-- The Edge Function uses the Service Role key which bypasses RLS, 
-- but we will keep it safe from public access.
create policy "Only service role can access credentials"
on public.google_oauth_credentials
using (false)
with check (false);
