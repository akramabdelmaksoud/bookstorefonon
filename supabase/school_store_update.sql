-- Generalises "books" to any school/university item: author -> brand, publisher -> details.
-- Run after owner_upgrade.sql.
alter table products rename column author to brand;
alter table products rename column publisher to details;
do $$
declare def text := pg_get_functiondef('public.dashboard_stats(date,date)'::regprocedure);
begin
  execute replace(def, 'p.author', 'p.brand');
end $$;
