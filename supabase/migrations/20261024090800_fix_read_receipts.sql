
-- Allow users to update messages in their conversations (mark as read)
create policy "Users can update messages in their conversations"
on public.messages for update
using (
  conversation_id in (
    select id from public.conversations 
    where user1_id = auth.uid() or user2_id = auth.uid()
  )
);
