-- Reserved private buckets; writes remain disabled until upload validation is implemented.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('household-images', 'household-images', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('inventory-photos', 'inventory-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('repair-attachments', 'repair-attachments', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('chat-attachments', 'chat-attachments', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- household UUID is the first directory. Validate before casting untrusted object names.
create function private.object_household(object_name text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return split_part(object_name, '/', 1)::uuid;
exception when invalid_text_representation then return null;
end $$;
revoke all on function private.object_household(text) from public, anon;
grant execute on function private.object_household(text) to authenticated;
create policy homecircle_private_object_read on storage.objects for select to authenticated
using (
  bucket_id in ('household-images', 'inventory-photos', 'repair-attachments', 'chat-attachments')
  and private.is_member(private.object_household(name))
);
-- No INSERT/UPDATE/DELETE policies: reserved buckets cannot be uploaded to by clients yet.
-- No realtime publication/broadcast policies until event tables and payloads are designed.
