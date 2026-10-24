-- 1. Create a "conversations" table to group messages
create table public.conversations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  user1_id uuid references public.profiles(id) not null,
  user2_id uuid references public.profiles(id) not null,
  last_message text,
  last_message_time timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Add a conversation_id and read status to the messages table
alter table public.messages 
  add column conversation_id uuid references public.conversations(id) on delete cascade,
  add column is_read boolean default false;

-- 3. Turn on RLS for conversations
alter table public.conversations enable row level security;

create policy "Users can view their own conversations."
on public.conversations for select
using (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "Users can insert conversations."
on public.conversations for insert
with check (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "Users can update their own conversations."
on public.conversations for update
using (auth.uid() = user1_id or auth.uid() = user2_id);

-- 4. Enable Realtime for conversations
alter publication supabase_realtime add table public.conversations;


============================================================
