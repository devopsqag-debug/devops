-- =============================================
-- BARBERSHOP BOOKING APP - INITIAL SCHEMA
-- =============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =============================================
-- SERVICES TABLE
-- =============================================
create table if not exists public.services (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  duration_minutes integer not null default 30,
  price_cents integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- =============================================
-- BOOKINGS TABLE
-- =============================================
create table if not exists public.bookings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete restrict,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled', 'completed')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =============================================
-- INDEXES
-- =============================================
create index if not exists idx_bookings_user_id on public.bookings(user_id);
create index if not exists idx_bookings_service_id on public.bookings(service_id);
create index if not exists idx_bookings_start_time on public.bookings(start_time);
create index if not exists idx_bookings_status on public.bookings(status);

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
alter table public.services enable row level security;
alter table public.bookings enable row level security;

-- Services: anyone can read active services
create policy "Anyone can view active services"
  on public.services for select
  using (is_active = true);

-- Services: only service role can insert/update/delete
create policy "Service role can manage services"
  on public.services for all
  using (auth.role() = 'service_role');

-- Bookings: users can only read their own bookings
create policy "Users can view their own bookings"
  on public.bookings for select
  using (auth.uid() = user_id);

-- Bookings: users can only insert their own bookings
create policy "Users can create their own bookings"
  on public.bookings for insert
  with check (auth.uid() = user_id);

-- Bookings: users can only update their own bookings (e.g., cancel)
create policy "Users can update their own bookings"
  on public.bookings for update
  using (auth.uid() = user_id);

-- =============================================
-- SEED DATA - SAMPLE SERVICES
-- =============================================
insert into public.services (name, description, duration_minutes, price_cents) values
  ('Haircut', 'Classic haircut with styling. Includes wash and blow-dry.', 45, 3500),
  ('Beard Trim', 'Professional beard shaping and trimming to your desired style.', 30, 2000),
  ('Hot Towel Shave', 'Luxurious straight razor shave with hot towel treatment.', 45, 4500)
on conflict do nothing;

-- =============================================
-- FUNCTION: Prevent double bookings
-- =============================================
create or replace function public.check_booking_availability()
returns trigger as $$
begin
  if exists (
    select 1 from public.bookings
    where id != coalesce(new.id, '')
    and status != 'cancelled'
    and (
      (new.start_time, new.end_time) overlaps (start_time, end_time)
    )
  ) then
    raise exception 'This time slot is already booked. Please choose another time.';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger prevent_double_booking
  before insert or update on public.bookings
  for each row execute function public.check_booking_availability();
