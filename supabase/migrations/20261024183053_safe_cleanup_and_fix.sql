
-- 1. Drop unused tables (cascade removes old policies)
drop table if exists public.otp_codes cascade;
drop table if exists public.google_tokens cascade;
drop table if exists public.google_oauth_credentials cascade;
drop table if exists public.email_code_rate_limits cascade;

-- 2. Fix RLS policies for messages
drop policy if exists "Users can update messages in their conversations" on public.messages;
drop policy if exists "Users can insert their own messages." on public.messages;
drop policy if exists "Messages are viewable by everyone." on public.messages;

create policy "Messages are viewable by everyone" 
on public.messages for select using (true);

create policy "Users can insert their own messages" 
on public.messages for insert 
with check (auth.uid() = sender_id);

create policy "Users can update messages in their conversations" 
on public.messages for update
using (
  conversation_id in (
    select id from public.conversations 
    where user1_id = auth.uid() or user2_id = auth.uid()
  )
);

-- 3. Fix RLS policies for calls
drop policy if exists "Users can see calls involving them" on public.calls;
drop policy if exists "Users can create calls" on public.calls;
drop policy if exists "Users can update calls they are part of" on public.calls;

create policy "Users can see calls involving them" 
on public.calls for select 
using (auth.uid() = caller_id or auth.uid() = receiver_id);

create policy "Users can create calls" 
on public.calls for insert 
with check (auth.uid() = caller_id);

create policy "Users can update calls they are part of" 
on public.calls for update 
using (auth.uid() = caller_id or auth.uid() = receiver_id);

-- 4. Safely add tables to realtime (only if not already there)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'calls') then
    alter publication supabase_realtime add table public.calls;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'analytics') then
    alter publication supabase_realtime add table public.analytics;
  end if;
end $$;

-- 5. Ensure chat_media bucket is public
update storage.buckets set public = true where id = 'chat_media';
