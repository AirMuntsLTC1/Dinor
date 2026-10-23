
create table public.google_tokens (
  id integer primary key default 1,
  refresh_token text not null
);
alter table public.google_tokens enable row level security;
