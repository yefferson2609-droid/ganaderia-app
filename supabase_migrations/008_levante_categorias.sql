-- "Levante y ceba": categoría ganadera y fecha de destete.
-- Se puede ejecutar varias veces sin problema.

alter table terneros add column if not exists categoria text;
alter table terneros add column if not exists fecha_destete date;

notify pgrst, 'reload schema';
