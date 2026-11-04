# Supabase PostgreSQL trust root

`supabase-root-2021.pem` is Supabase's public CA, used to verify its hosted session-pooler certificate. It contains no private key or application credential.

Source: https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt

SHA-256: `807025ad50d4ed219d2c9c7d299c004f824eb00cf7f65afef607d07b72e6cafa`

Keep `DATABASE_SSLMODE=verify-full`. The local backend configuration uses this certificate through `DATABASE_SSLROOTCERT`; its path is resolved from the directory where the backend is launched. Update the CA from the project's trusted Supabase Dashboard certificate download when Supabase rotates it.

Reference: [Supabase SSL enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement).
