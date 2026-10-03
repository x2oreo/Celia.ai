-- One confirmation per device for AI-found boxes (box-identify): an AI web answer is shared with everyone only
-- after AI_CONFIRMATIONS_NEEDED distinct devices said "yes, this is my box". voter_hash = sha256(secret salt |
-- gtin | client address) — nothing personal in clear. Only the edge function (service role) reads or writes it.

create table if not exists box_confirmations (
  gtin        text not null references box_cache (gtin) on delete cascade,
  voter_hash  text not null check (voter_hash ~ '^[0-9a-f]{64}$'),
  created_at  timestamptz not null default now(),
  primary key (gtin, voter_hash)
);

alter table box_confirmations enable row level security;
-- No policies: anon and authenticated clients can neither read nor write.

-- Earlier single-vote confirmations no longer count as "shared" (the threshold is now 2 distinct devices).
update box_cache set confirmations = least(confirmations, 1) where method = 'AI_WEB';
