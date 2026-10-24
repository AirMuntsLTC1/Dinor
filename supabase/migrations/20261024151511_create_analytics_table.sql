
create table public.analytics (
  id uuid default gen_random_uuid() primary key,
  event_type text not null,
  metadata jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Allow public insert (for app tracking)
alter table public.analytics enable row level security;
create policy "Anyone can insert analytics" on public.analytics for insert with check (true);

-- Allow only developers to read (You can change 'authenticated' to specific email if needed)
create policy "Admins can read analytics" on public.analytics for select to authenticated using (true);


============================================================
