-- Curated LQTS drug list for the online /drug-check path. Same data as the app's bundled dataset
-- (app/entry/src/main/ets/drugs/DrugDataset.ets → data/export_seed.py → seed.sql).
-- Read-only for the public anon key (RLS). No personal data is ever stored here.

create table if not exists drugs (
  ingredient   text primary key,
  risk         text not null check (risk in ('KNOWN_RISK','POSSIBLE_RISK','CONDITIONAL_RISK','NOT_LISTED')),
  drug_class   text not null,
  avoid_congenital boolean not null default false
);

create table if not exists drug_aliases (
  alias       text primary key,
  ingredient  text not null references drugs(ingredient) on delete cascade
);

alter table drugs enable row level security;
alter table drug_aliases enable row level security;

create policy "drugs are public read" on drugs for select using (true);
create policy "aliases are public read" on drug_aliases for select using (true);
