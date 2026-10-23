-- Create OTP Codes table
create table public.otp_codes (
  email text primary key,
  code text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (Row Level Security)
alter table public.otp_codes enable row level security;

-- Allow the Edge Function (service_role) to read/write, but deny public access
create policy "Only service role can access OTPs"
on public.otp_codes
using (false)
with check (false);
