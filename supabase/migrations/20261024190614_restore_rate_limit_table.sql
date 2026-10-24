
-- Re-create the table for rate limiting email codes
create table if not exists public.email_code_rate_limits (
  email text primary key,
  last_sent_at timestamp with time zone default timezone('utc'::text, now()) not null,
  window_started_at timestamp with time zone default timezone('utc'::text, now()) not null,
  request_count integer default 1 not null
);

-- Enable RLS (Row Level Security)
alter table public.email_code_rate_limits enable row level security;

-- The Edge Function uses the Service Role key, which bypasses RLS by default.
-- So we only need to ensure the table exists for the function to use.
