-- Africa Sport Edition: profils Auth, données partagées et stockage privé.
create table if not exists public.ase_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null default '',
  phone text, country text, city text, agency text, position text, motivation text,
  requested_role text not null default 'Joueur'
    check (requested_role in ('Joueur','Club','Académie','Scout','Agent','Média','Investisseur')),
  role text not null default 'member'
    check (role in ('member','player','club','academy','scout','agent','media','investor','admin')),
  status text not null default 'pending'
    check (status in ('pending','active','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.ase_is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.ase_profiles p where p.id = auth.uid() and p.role = 'admin' and p.status = 'active') $$;
create or replace function public.ase_is_active()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.ase_profiles p where p.id = auth.uid() and p.status = 'active') $$;
create or replace function public.ase_can_edit_shared_data()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.ase_profiles p where p.id=auth.uid() and p.status='active' and p.role in ('admin','scout','club','academy','agent')) $$;
create or replace function public.ase_profile_bootstrap()
returns trigger language plpgsql security definer set search_path = public
as $$
declare requested text;
begin
  requested := coalesce(new.raw_user_meta_data->>'requested_role','Joueur');
  if requested not in ('Joueur','Club','Académie','Scout','Agent','Média','Investisseur') then requested := 'Joueur'; end if;
  insert into public.ase_profiles(id,email,display_name,phone,country,city,agency,position,motivation,requested_role,role,status)
  values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'display_name',''),new.raw_user_meta_data->>'phone',new.raw_user_meta_data->>'country',new.raw_user_meta_data->>'city',new.raw_user_meta_data->>'agency',new.raw_user_meta_data->>'position',new.raw_user_meta_data->>'motivation',requested,'member','pending')
  on conflict (id) do update set email=excluded.email;
  return new;
end;
$$;
drop trigger if exists ase_auth_profile_bootstrap on auth.users;
create trigger ase_auth_profile_bootstrap after insert on auth.users
for each row execute procedure public.ase_profile_bootstrap();

create table if not exists public.ase_user_data (
  user_id uuid not null references auth.users(id) on delete cascade,
  collection text not null check (collection in ('watchlist','followed-clubs','followed-events','profile-draft')),
  payload jsonb not null, updated_at timestamptz not null default now(),
  primary key(user_id,collection)
);

create table if not exists public.ase_app_data (
  collection text primary key check (collection in ('players','club-directory','reports','player-profiles','events','transfers','users','requests','codes','admin-profile','payments')),
  payload jsonb not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.ase_profiles enable row level security;
alter table public.ase_app_data enable row level security;
alter table public.ase_user_data enable row level security;
revoke all on public.ase_profiles from anon;
revoke all on public.ase_app_data from anon;
revoke all on public.ase_user_data from anon;
grant select, update, delete on public.ase_profiles to authenticated;
grant select, insert, update, delete on public.ase_app_data to authenticated;
grant select, insert, update, delete on public.ase_user_data to authenticated;
revoke all on function public.ase_is_admin() from public, anon;
revoke all on function public.ase_can_edit_shared_data() from public, anon;
revoke all on function public.ase_is_active() from public, anon;

revoke all on function public.ase_profile_bootstrap() from public, anon, authenticated;
grant execute on function public.ase_is_admin() to authenticated;
grant execute on function public.ase_is_active() to authenticated;
grant execute on function public.ase_can_edit_shared_data() to authenticated;

 drop policy if exists ase_profiles_select_self_or_admin on public.ase_profiles;
create policy ase_profiles_select_self_or_admin on public.ase_profiles for select to authenticated
using (id = (select auth.uid()) or (select public.ase_is_admin()));
drop policy if exists ase_profiles_update_admin on public.ase_profiles;
create policy ase_profiles_update_admin on public.ase_profiles for update to authenticated
using ((select public.ase_is_admin())) with check ((select public.ase_is_admin()));
drop policy if exists ase_profiles_delete_admin on public.ase_profiles;
create policy ase_profiles_delete_admin on public.ase_profiles for delete to authenticated
using ((select public.ase_is_admin()));

drop policy if exists ase_app_data_read_active on public.ase_app_data;
create policy ase_app_data_read_active on public.ase_app_data for select to authenticated
using ((select public.ase_is_active()) and ((select public.ase_is_admin()) or collection not in ('users','requests','codes','admin-profile','payments')));
drop policy if exists ase_app_data_insert_allowed on public.ase_app_data;
create policy ase_app_data_insert_allowed on public.ase_app_data for insert to authenticated
with check ((select public.ase_is_active()) and ((select public.ase_is_admin()) or ((select public.ase_can_edit_shared_data()) and collection in ('players','club-directory','reports','player-profiles','events','transfers'))));
drop policy if exists ase_app_data_update_allowed on public.ase_app_data;
create policy ase_app_data_update_allowed on public.ase_app_data for update to authenticated
using ((select public.ase_is_active()) and ((select public.ase_is_admin()) or ((select public.ase_can_edit_shared_data()) and collection in ('players','club-directory','reports','player-profiles','events','transfers'))))
with check ((select public.ase_is_active()) and ((select public.ase_is_admin()) or ((select public.ase_can_edit_shared_data()) and collection in ('players','club-directory','reports','player-profiles','events','transfers'))));
drop policy if exists ase_app_data_delete_allowed on public.ase_app_data;
create policy ase_app_data_delete_allowed on public.ase_app_data for delete to authenticated
using ((select public.ase_is_active()) and ((select public.ase_is_admin()) or ((select public.ase_can_edit_shared_data()) and collection in ('players','club-directory','reports','player-profiles','events','transfers'))));

-- Le bucket est public pour afficher les portraits et logos partagés ; ne pas y téléverser de pièces confidentielles.
insert into storage.buckets(id,name,public) values ('ase-media','ase-media',true)
on conflict (id) do nothing;
drop policy if exists ase_media_read_active on storage.objects;
create policy ase_media_read_active on storage.objects for select to authenticated
using (bucket_id='ase-media' and (select public.ase_is_active()));
drop policy if exists ase_media_upload_own on storage.objects;
create policy ase_media_upload_own on storage.objects for insert to authenticated
with check (bucket_id='ase-media' and (select public.ase_is_active()) and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists ase_media_update_own on storage.objects;
create policy ase_media_update_own on storage.objects for update to authenticated
using (bucket_id='ase-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.ase_is_admin())))
with check (bucket_id='ase-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.ase_is_admin())));
drop policy if exists ase_media_delete_own on storage.objects;
create policy ase_media_delete_own on storage.objects for delete to authenticated
using (bucket_id='ase-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.ase_is_admin())));


drop policy if exists ase_user_data_owner on public.ase_user_data;
create policy ase_user_data_owner on public.ase_user_data for all to authenticated
using (user_id=(select auth.uid()) and (select public.ase_is_active()))
with check (user_id=(select auth.uid()) and (select public.ase_is_active()));
