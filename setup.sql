-- Run once in Supabase: SQL Editor > New query > paste > Run
-- 1) CHANGE the invite code below before running. Friends need it to join.
create table profiles(id uuid primary key references auth.users on delete cascade, name text not null);
create table app_settings(k text primary key, v text);
insert into app_settings values('invite','CHANGE-ME');
create table checkins(
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references profiles(id),
  spot text not null, dish text,
  stars int not null check(stars between 1 and 5),
  crisp int, sauce int, portion int, note text, photo_path text,
  lat double precision not null, lng double precision not null,
  created_at timestamptz default now());
alter table profiles enable row level security;
alter table checkins enable row level security;
alter table app_settings enable row level security;
create function is_member() returns boolean language sql security definer stable set search_path=public
  as $$ select exists(select 1 from profiles where id=auth.uid()) $$;
create policy p_sel on profiles for select using (is_member());
create policy c_sel on checkins for select using (is_member());
create policy c_ins on checkins for insert with check (user_id=auth.uid() and is_member());
create policy c_del on checkins for delete using (user_id=auth.uid());
create function join_group(p_name text, p_code text) returns void language plpgsql security definer set search_path=public as $$
begin
  if p_code is distinct from (select v from app_settings where k='invite') then raise exception 'Wrong invite code'; end if;
  insert into profiles(id,name) values(auth.uid(),p_name) on conflict (id) do update set name=excluded.name;
end $$;
insert into storage.buckets(id,name,public) values('photos','photos',true);
create policy ph_ins on storage.objects for insert to authenticated with check (bucket_id='photos' and is_member());

-- Admin (run once, later): lets the first member delete anyone's check-ins
create table if not exists admins(id uuid primary key);
alter table admins enable row level security;
create policy a_sel on admins for select using (id=auth.uid());
create policy c_del_admin on checkins for delete using (exists(select 1 from admins where id=auth.uid()));

-- Lets you delete a user (and their check-ins) from the Supabase dashboard
alter table checkins drop constraint checkins_user_id_fkey, add constraint checkins_user_id_fkey foreign key (user_id) references profiles(id) on delete cascade;
