-- Removes the mock demo data (books with barcode DEMO-*, their sales/returns/purchases,
-- demo suppliers, demo expenses, demo shifts, demo categories). Real data is left alone.
delete from refund_items where product_id in (select id from products where barcode like 'DEMO-%');
delete from refunds where id not in (select refund_id from refund_items);
delete from purchase_items where product_id in (select id from products where barcode like 'DEMO-%');
delete from purchases where id not in (select purchase_id from purchase_items);
delete from stock_logs where product_id in (select id from products where barcode like 'DEMO-%');
delete from transaction_items where product_id in (select id from products where barcode like 'DEMO-%');
delete from transactions where id not in (select transaction_id from transaction_items);
delete from shifts where note like '%[demo]%';
delete from expenses where note like 'DEMO%';
delete from suppliers where name like 'Demo · %';
delete from products where barcode like 'DEMO-%';
delete from categories where name like 'Demo · %';
-- demo categories without the prefix (only if now empty)
delete from categories c where c.name in ('Backpacks & Bags','Notebooks & Paper','Pens & Pencils','Art & Craft','Geometry & Calculators','Folders & Files','Uniform & Lab','Electronics & Accessories','Textbooks','Lunch & Bottles') and not exists (select 1 from products p where p.category_id = c.id);
