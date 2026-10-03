-- Cache of QT verdicts derived from openFDA labels (functions/_shared/labelRisk.ts) for ingredients that are NOT in
-- the curated `drugs` table. Public data only (ingredient names + label text), no personal data.
-- Read-only for anon; only the edge function (service role) writes. Rows older than 30 days are refetched.

create table if not exists label_cache (
  ingredient  text primary key,
  risk        text not null check (risk in ('KNOWN_RISK','POSSIBLE_RISK','CONDITIONAL_RISK','NOT_LISTED','NO_LABEL')),
  section     text not null default '',
  snippet     text not null default '',
  set_id      text not null default '',
  fetched_at  timestamptz not null default now()
);

alter table label_cache enable row level security;

create policy "label cache is public read" on label_cache for select using (true);
;
