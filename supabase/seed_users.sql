-- Creates one admin and one cashier. Run in the Supabase SQL editor AFTER schema.sql.
-- EDIT the four values below in the SQL editor (never commit real passwords), then run.
do $$
declare
  v_admin_email   text := 'admin@example.com';      -- <-- change
  v_admin_pass    text := 'CHANGE_ME_ADMIN_PASS';   -- <-- change
  v_cashier_email text := 'cashier@example.com';    -- <-- change
  v_cashier_pass  text := 'CHANGE_ME_CASHIER_PASS'; -- <-- change
  v_id uuid;
  r record;
begin
  for r in select * from (values
      (v_admin_email, v_admin_pass, 'admin'),
      (v_cashier_email, v_cashier_pass, 'cashier')) as t(email, pass, role)
  loop
    if exists (select 1 from auth.users where email = r.email) then
      raise notice 'skipping %, already exists', r.email;
      continue;
    end if;
    v_id := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', r.email,
            crypt(r.pass, gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), v_id, v_id::text,
            jsonb_build_object('sub', v_id::text, 'email', r.email, 'email_verified', true),
            'email', now(), now(), now());
    -- handle_new_user() trigger already created the profile; set the role.
    update profiles set role = r.role where id = v_id;
  end loop;
end $$;
