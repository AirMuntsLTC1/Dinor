
-- Allow all authenticated users to view all profiles (so they can be searched)
create policy "Authenticated users can view all profiles"
on public.profiles for select
to authenticated
using (true);

-- Allow users to update their own profile
create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id);


============================================================
