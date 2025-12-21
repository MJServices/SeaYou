-- Entitlements table
create table if not exists public.entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text check (tier in ('free','premium','elite')) not null default 'free',
  source text default 'manual',
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.entitlements enable row level security;
create policy entitlements_select on public.entitlements for select using (auth.uid() = user_id);
create policy entitlements_upsert on public.entitlements for insert with check (auth.uid() = user_id);
create policy entitlements_update on public.entitlements for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Base tables (create if missing)
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references auth.users(id) on delete cascade,
  user_b_id uuid not null references auth.users(id) on delete cascade,
  title text,
  exchanges_count int default 0,
  feeling_percent int default 0,
  unlock_state int default 0,
  last_sender_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.conversations enable row level security;
create policy conversations_participants_select on public.conversations for select using (
  auth.uid() = user_a_id or auth.uid() = user_b_id
);
create policy conversations_participants_update on public.conversations for update using (
  auth.uid() = user_a_id or auth.uid() = user_b_id
) with check (
  auth.uid() = user_a_id or auth.uid() = user_b_id
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  type text check (type in ('text','voice','photo','quote')) default 'text',
  text text,
  media_url text,
  qa_group_id uuid,
  is_question boolean default false,
  is_answer boolean default false,
  feeling_delta int default 0,
  created_at timestamptz default now()
);

alter table public.messages enable row level security;
create policy messages_participants_select on public.messages for select using (
  exists(select 1 from public.conversations c where c.id = conversation_id and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id))
);
create policy messages_participants_insert on public.messages for insert with check (
  exists(select 1 from public.conversations c where c.id = conversation_id and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id))
);

-- Conversations updates (if not present)
alter table public.conversations add column if not exists exchanges_count int default 0;
alter table public.conversations add column if not exists feeling_percent int default 0;
alter table public.conversations add column if not exists unlock_state int default 0; -- 0..4 for 0/25/50/75/100
alter table public.conversations add column if not exists last_sender_id uuid;

-- Messages QA metadata
alter table public.messages add column if not exists qa_group_id uuid;
alter table public.messages add column if not exists is_question boolean default false;
alter table public.messages add column if not exists is_answer boolean default false;
alter table public.messages add column if not exists feeling_delta int default 0;





-- Trigger to update conversation stats on new message
create or replace function public.fn_update_conversation_on_message() returns trigger as $$
begin
  update public.conversations c
    set exchanges_count = coalesce(c.exchanges_count,0) + 1,
        last_sender_id = NEW.sender_id,
        feeling_percent = least(100, coalesce(c.feeling_percent,0) + coalesce(NEW.feeling_delta, 0)),
        unlock_state = case 
            when feeling_percent >= 100 then 4 
            when feeling_percent >= 75 then 3
            when feeling_percent >= 50 then 2
            when feeling_percent >= 25 then 1
            else 0 end,
        updated_at = now()
    where c.id = NEW.conversation_id;
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_update_conversation_on_message on public.messages;
create trigger trg_update_conversation_on_message
after insert on public.messages
for each row execute procedure public.fn_update_conversation_on_message();
