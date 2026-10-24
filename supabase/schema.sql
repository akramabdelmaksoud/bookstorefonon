-- Bookstore POS schema. Run once in Supabase SQL editor.
create extension if not exists "pgcrypto";

-- ---------- Tables ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'cashier' check (role in ('cashier','admin')),
  created_at timestamptz not null default now()
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  barcode text not null unique,
  purchase_price numeric(12,2) not null default 0 check (purchase_price >= 0),
  selling_price numeric(12,2) not null check (selling_price >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  category_id uuid references categories(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  cashier_id uuid not null references auth.users(id),
  total_amount numeric(12,2) not null,
  payment_method text not null default 'cash',
  created_at timestamptz not null default now()
);

create table if not exists transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references transactions(id) on delete cascade,
  product_id uuid not null references products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null,
  total_price numeric(12,2) not null
);

create table if not exists stock_logs (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  change_type text not null check (change_type in ('sale','restock','manual_adjustment')),
  quantity_changed integer not null,
  previous_stock integer not null,
  new_stock integer not null,
  reason text,
  performed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_tx_created on transactions(created_at desc);
create index if not exists idx_txi_tx on transaction_items(transaction_id);
create index if not exists idx_txi_product on transaction_items(product_id);
create index if not exists idx_logs_product on stock_logs(product_id, created_at desc);
create index if not exists idx_logs_created on stock_logs(created_at desc);

-- ---------- Helpers ----------
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Auto-create a cashier profile for each new auth user.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name) values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ---------- Atomic sale ----------
-- p_items: [{"product_id": "...", "quantity": 2}, ...]
-- Prices are read server-side so a client can never tamper with them.
create or replace function complete_sale(p_items jsonb, p_payment_method text default 'cash')
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_tx uuid;
  v_total numeric(12,2) := 0;
  v_item jsonb;
  v_prod products%rowtype;
  v_qty int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if jsonb_array_length(p_items) = 0 then raise exception 'empty cart'; end if;

  insert into transactions (cashier_id, total_amount, payment_method)
  values (auth.uid(), 0, p_payment_method) returning id into v_tx;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::int;
    if v_qty <= 0 then raise exception 'invalid quantity'; end if;

    select * into v_prod from products
      where id = (v_item->>'product_id')::uuid for update;
    if not found then raise exception 'product not found'; end if;
    if v_prod.stock_quantity < v_qty then
      raise exception 'insufficient stock for %', v_prod.name;
    end if;

    update products set stock_quantity = stock_quantity - v_qty where id = v_prod.id;

    insert into transaction_items (transaction_id, product_id, quantity, unit_price, total_price)
    values (v_tx, v_prod.id, v_qty, v_prod.selling_price, v_prod.selling_price * v_qty);

    insert into stock_logs (product_id, change_type, quantity_changed, previous_stock, new_stock, reason, performed_by)
    values (v_prod.id, 'sale', -v_qty, v_prod.stock_quantity, v_prod.stock_quantity - v_qty,
            'Sale ' || v_tx, auth.uid());

    v_total := v_total + v_prod.selling_price * v_qty;
  end loop;

  update transactions set total_amount = v_total where id = v_tx;
  return v_tx;
end $$;

-- ---------- Admin stock adjustment (restock / manual) ----------
create or replace function adjust_stock(p_product_id uuid, p_delta int, p_type text, p_reason text)
returns void
language plpgsql security definer set search_path = public as $$
declare v_prod products%rowtype;
begin
  if not is_admin() then raise exception 'admin only'; end if;
  if p_type not in ('restock','manual_adjustment') then raise exception 'bad type'; end if;
  select * into v_prod from products where id = p_product_id for update;
  if not found then raise exception 'product not found'; end if;
  if v_prod.stock_quantity + p_delta < 0 then raise exception 'stock cannot go negative'; end if;
  update products set stock_quantity = stock_quantity + p_delta where id = p_product_id;
  insert into stock_logs (product_id, change_type, quantity_changed, previous_stock, new_stock, reason, performed_by)
  values (p_product_id, p_type, p_delta, v_prod.stock_quantity, v_prod.stock_quantity + p_delta, p_reason, auth.uid());
end $$;

-- ---------- Row Level Security ----------
alter table profiles enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table transactions enable row level security;
alter table transaction_items enable row level security;
alter table stock_logs enable row level security;

create policy "own profile or admin" on profiles for select
  using (id = auth.uid() or is_admin());

create policy "read categories" on categories for select to authenticated using (true);
create policy "admin writes categories" on categories for all using (is_admin()) with check (is_admin());

create policy "read products" on products for select to authenticated using (true);
create policy "admin writes products" on products for all using (is_admin()) with check (is_admin());

-- Sales are written only through complete_sale (security definer), so no insert policies.
create policy "cashier reads own tx, admin all" on transactions for select
  using (cashier_id = auth.uid() or is_admin());
create policy "items follow tx" on transaction_items for select
  using (exists (select 1 from transactions t where t.id = transaction_id
                 and (t.cashier_id = auth.uid() or is_admin())));
create policy "admin reads logs" on stock_logs for select using (is_admin());

revoke execute on function adjust_stock(uuid,int,text,text) from anon;
revoke execute on function complete_sale(jsonb,text) from anon;

-- Realtime for the admin dashboard
alter publication supabase_realtime add table stock_logs, transactions, products;

-- Promote the owner after creating their account:
--   update profiles set role = 'admin' where id = '<owner auth uid>';
