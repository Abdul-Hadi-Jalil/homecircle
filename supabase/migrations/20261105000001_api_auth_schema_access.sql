-- RLS expressions call auth.uid() as the restricted API role. Hosted Auth schema
-- permissions can differ from local defaults; make this dependency explicit.
grant usage on schema auth to homecircle_api;
grant execute on function auth.uid() to homecircle_api;
