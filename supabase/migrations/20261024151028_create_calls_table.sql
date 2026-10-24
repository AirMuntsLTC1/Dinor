
create table public.calls (
  id uuid default gen_random_uuid() primary key,
  caller_id uuid references public.profiles(id) not null,
  receiver_id uuid references public.profiles(id) not null,
  conversation_id uuid references public.conversations(id) not null,
  status text default 'ringing' not null, -- 'ringing', 'active', 'ended'
  offer jsonb,
  answer jsonb,
  caller_ice jsonb default '[]'::jsonb,
  receiver_ice jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.calls enable row level security;

create policy "Users can see calls involving them"
on public.calls for select
using (auth.uid() = caller_id or auth.uid() = receiver_id);

create policy "Users can create calls"
on public.calls for insert
with check (auth.uid() = caller_id);

create policy "Users can update calls they are part of"
on public.calls for update
using (auth.uid() = caller_id or auth.uid() = receiver_id);

alter publication supabase_realtime add table public.calls;


============================================================
