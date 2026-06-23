-- RLS policies only filter rows; Postgres still requires base table-level
-- GRANTs for the anon/authenticated roles before RLS is ever evaluated.
-- The initial schema migration created tables without granting these,
-- which caused "permission denied for table X" (42501) for every query.
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to anon, authenticated;
