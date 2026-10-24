
-- 1. Allow public read access to chat_media
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'chat_media' );

-- 2. Allow authenticated users to upload to chat_media
create policy "Auth Upload"
on storage.objects for insert
with check (
  bucket_id = 'chat_media' 
  AND auth.role() = 'authenticated'
);


============================================================
