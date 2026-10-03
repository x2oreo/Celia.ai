-- Barcode → medicine box cache for /box-identify (any country). Public product facts only, never who scanned it.
-- REGISTRY / PRODUCT_DB rows come from deterministic sources and are served at once. AI_WEB rows are served only
-- after a user confirmed the box (confirmations >= 1). Read-only for anon; only the edge function writes.

create table if not exists box_cache (
  gtin           text primary key check (gtin ~ '^[0-9]{8,13}$'),
  brand          text not null,
  ingredients    text[] not null,
  unresolved     text[] not null default '{}',
  strength       text not null default '',
  form           text not null default '',
  country        text not null default '',
  method         text not null check (method in ('REGISTRY','PRODUCT_DB','AI_WEB')),
  source         text not null default '',
  source_url     text not null default '',
  confirmations  integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table box_cache enable row level security;

create policy "box cache is public read" on box_cache for select using (true);
;
