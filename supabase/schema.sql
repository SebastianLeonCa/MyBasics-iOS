-- =============================================================================
-- MyBasics · esquema de base de datos (Supabase / Postgres)
--
-- Cómo usarlo: Supabase › SQL Editor › New query › pega TODO este archivo › Run.
-- Es idempotente: puedes volver a ejecutarlo sin perder datos.
--
-- Dinero: siempre entero en centavos (amount_cents). Nunca float/numeric.
-- Seguridad: RLS activado en todas las tablas; cada usuario solo ve sus filas.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------

create table if not exists public.categories (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name        text not null check (char_length(trim(name)) between 1 and 40),
    color_hex   text not null default '#8E8E93' check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    icon        text not null default 'tag' check (char_length(icon) between 1 and 60),
    is_default  boolean not null default false,
    created_at  timestamptz not null default now(),
    constraint categories_user_name_key unique (user_id, name)
);

create table if not exists public.expenses (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
    -- NO ACTION (no RESTRICT): se verifica al final de la sentencia, así borrar un usuario
    -- elimina en cascada sus categorías y gastos sin chocar entre sí.
    category_id  uuid not null references public.categories (id) on delete no action,
    amount_cents integer not null check (amount_cents > 0),
    -- Sin moneda por gasto: la moneda es una sola, la del perfil (profiles.currency).
    kind         text not null default 'variable' check (kind in ('fixed', 'variable')),
    note         text check (note is null or char_length(note) <= 200),
    spent_at     timestamptz not null default now(),
    created_at   timestamptz not null default now()
);

-- "debts" en la base de datos; en la app se muestran como "Compartidos".
create table if not exists public.debts (
    id                uuid primary key default gen_random_uuid(),
    expense_id        uuid not null references public.expenses (id) on delete cascade,
    user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
    counterparty_name text not null check (char_length(trim(counterparty_name)) between 1 and 80),
    amount_cents      integer not null check (amount_cents > 0),
    direction         text not null check (direction in ('they_owe_me', 'i_owe_them')),
    is_settled        boolean not null default false,
    settled_at        timestamptz,
    created_at        timestamptz not null default now()
);


-- Perfil: una fila por usuario. Única fuente de verdad de la moneda con la que se muestran
-- todos los montos (es solo el símbolo: los montos nunca se convierten).
create table if not exists public.profiles (
    user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    currency   text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
    updated_at timestamptz not null default now()
);

-- Migración: antes cada gasto guardaba su moneda. Se pasa al perfil la del gasto más reciente
-- de cada usuario y se elimina la columna, para que no haya dos fuentes de verdad.
do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'expenses' and column_name = 'currency'
    ) then
        execute $sql$
            insert into public.profiles (user_id, currency)
            select distinct on (user_id) user_id, currency
            from public.expenses
            order by user_id, spent_at desc
            on conflict (user_id) do nothing
        $sql$;
        alter table public.expenses drop column currency;
    end if;
end;
$$;

-- Migración (Fase 4): proyectos creados con la versión anterior tenían ON DELETE RESTRICT.
alter table public.expenses drop constraint if exists expenses_category_id_fkey;
alter table public.expenses add constraint expenses_category_id_fkey
    foreign key (category_id) references public.categories (id) on delete no action;


-- -----------------------------------------------------------------------------
-- Índices
-- -----------------------------------------------------------------------------

create index if not exists expenses_user_spent_at_idx on public.expenses (user_id, spent_at desc);
create index if not exists expenses_category_idx      on public.expenses (category_id);
create index if not exists categories_user_idx        on public.categories (user_id);
create index if not exists debts_expense_idx          on public.debts (expense_id);
create index if not exists debts_user_pending_idx     on public.debts (user_id) where not is_settled;


-- -----------------------------------------------------------------------------
-- Row Level Security: "own rows"
-- -----------------------------------------------------------------------------

alter table public.categories enable row level security;
alter table public.expenses   enable row level security;
alter table public.debts      enable row level security;
alter table public.profiles   enable row level security;

-- profiles (sin DELETE: se borra en cascada al eliminar la cuenta)
drop policy if exists "own rows: select" on public.profiles;
drop policy if exists "own rows: insert" on public.profiles;
drop policy if exists "own rows: update" on public.profiles;
create policy "own rows: select" on public.profiles for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.profiles for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy "own rows: update" on public.profiles for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- categories
drop policy if exists "own rows: select" on public.categories;
drop policy if exists "own rows: insert" on public.categories;
drop policy if exists "own rows: update" on public.categories;
drop policy if exists "own rows: delete" on public.categories;
create policy "own rows: select" on public.categories for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.categories for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy "own rows: update" on public.categories for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own rows: delete" on public.categories for delete to authenticated
    using ((select auth.uid()) = user_id);

-- expenses (además: la categoría usada también debe ser del usuario)
drop policy if exists "own rows: select" on public.expenses;
drop policy if exists "own rows: insert" on public.expenses;
drop policy if exists "own rows: update" on public.expenses;
drop policy if exists "own rows: delete" on public.expenses;
create policy "own rows: select" on public.expenses for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.expenses for insert to authenticated
    with check (
        (select auth.uid()) = user_id
        and exists (select 1 from public.categories c where c.id = category_id and c.user_id = (select auth.uid()))
    );
create policy "own rows: update" on public.expenses for update to authenticated
    using ((select auth.uid()) = user_id)
    with check (
        (select auth.uid()) = user_id
        and exists (select 1 from public.categories c where c.id = category_id and c.user_id = (select auth.uid()))
    );
create policy "own rows: delete" on public.expenses for delete to authenticated
    using ((select auth.uid()) = user_id);

-- debts (además: el gasto asociado también debe ser del usuario)
drop policy if exists "own rows: select" on public.debts;
drop policy if exists "own rows: insert" on public.debts;
drop policy if exists "own rows: update" on public.debts;
drop policy if exists "own rows: delete" on public.debts;
create policy "own rows: select" on public.debts for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.debts for insert to authenticated
    with check (
        (select auth.uid()) = user_id
        and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
    );
create policy "own rows: update" on public.debts for update to authenticated
    using ((select auth.uid()) = user_id)
    with check (
        (select auth.uid()) = user_id
        and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
    );
create policy "own rows: delete" on public.debts for delete to authenticated
    using ((select auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- save_expense: crea o actualiza un gasto y sus montos compartidos en UNA transacción.
-- Se llama desde la app con supabase.rpc("save_expense", ...).
-- SECURITY INVOKER: corre con los permisos del usuario, así que las políticas RLS aplican.
-- Los montos compartidos que no vengan en p_debts se eliminan.
-- -----------------------------------------------------------------------------

create or replace function public.save_expense(p_expense jsonb, p_debts jsonb default '[]'::jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_id uuid := coalesce((p_expense ->> 'id')::uuid, gen_random_uuid());
begin
    if jsonb_typeof(p_debts) is distinct from 'array' then
        raise exception 'p_debts debe ser un arreglo JSON' using errcode = '22023';
    end if;

    insert into public.expenses (id, category_id, amount_cents, kind, note, spent_at)
    values (
        v_id,
        (p_expense ->> 'category_id')::uuid,
        (p_expense ->> 'amount_cents')::integer,
        coalesce(p_expense ->> 'kind', 'variable'),
        nullif(trim(p_expense ->> 'note'), ''),
        coalesce((p_expense ->> 'spent_at')::timestamptz, now())
    )
    on conflict (id) do update set
        category_id  = excluded.category_id,
        amount_cents = excluded.amount_cents,
        kind         = excluded.kind,
        note         = excluded.note,
        spent_at     = excluded.spent_at;

    -- Si el id existía pero es de otro usuario, RLS bloquea el UPDATE en silencio: lo detectamos.
    if not exists (select 1 from public.expenses where id = v_id) then
        raise exception 'Gasto no encontrado' using errcode = 'P0002';
    end if;

    delete from public.debts d
    where d.expense_id = v_id
      and d.id not in (
          select (x ->> 'id')::uuid from jsonb_array_elements(p_debts) x where x ->> 'id' is not null
      );

    insert into public.debts (id, expense_id, counterparty_name, amount_cents, direction, is_settled, settled_at)
    select
        coalesce((x ->> 'id')::uuid, gen_random_uuid()),
        v_id,
        trim(x ->> 'counterparty_name'),
        (x ->> 'amount_cents')::integer,
        x ->> 'direction',
        coalesce((x ->> 'is_settled')::boolean, false),
        (x ->> 'settled_at')::timestamptz
    from jsonb_array_elements(p_debts) x
    on conflict (id) do update set
        counterparty_name = excluded.counterparty_name,
        amount_cents      = excluded.amount_cents,
        direction         = excluded.direction,
        is_settled        = excluded.is_settled,
        settled_at        = excluded.settled_at;

    return v_id;
end;
$$;

revoke execute on function public.save_expense(jsonb, jsonb) from public, anon;
grant execute on function public.save_expense(jsonb, jsonb) to authenticated;


-- -----------------------------------------------------------------------------
-- delete_my_account: el usuario elimina su propia cuenta (requisito de App Store).
-- Borra la fila de auth.users; categorías, gastos y compartidos se van en cascada.
-- SECURITY DEFINER porque un usuario normal no puede tocar auth.users; solo borra auth.uid().
-- -----------------------------------------------------------------------------

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'No autenticado' using errcode = '42501';
    end if;
    delete from auth.users where id = v_uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- -----------------------------------------------------------------------------
-- Categorías por defecto: se siembran al crear un usuario (trigger en auth.users).
-- Los nombres se guardan en español; la app los traduce al mostrarlos.
-- -----------------------------------------------------------------------------

create or replace function public.seed_default_categories(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
    insert into public.categories (user_id, name, color_hex, icon, is_default, created_at)
    select p_user_id, d.name, d.color_hex, d.icon, true, now() + d.pos * interval '1 millisecond'
    from (values
        (1, 'Comida',        '#FF6B35', 'fork.knife'),
        (2, 'Supermercado',  '#2EC4B6', 'cart'),
        (3, 'Transporte',    '#3A86FF', 'car'),
        (4, 'Hogar',         '#8338EC', 'house'),
        (5, 'Suscripciones', '#5E60CE', 'repeat'),
        (6, 'Salud',         '#FF006E', 'cross.case'),
        (7, 'Ocio',          '#FFBE0B', 'gamecontroller'),
        (8, 'Otros',         '#8E8E93', 'ellipsis.circle')
    ) as d (pos, name, color_hex, icon)
    on conflict (user_id, name) do nothing;
$$;

-- Solo la usa el trigger; nadie la puede llamar desde la API.
revoke execute on function public.seed_default_categories(uuid) from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.seed_default_categories(new.id);
    insert into public.profiles (user_id) values (new.id) on conflict (user_id) do nothing;
    return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Usuarios que ya existían antes de correr este script también reciben sus categorías.
select public.seed_default_categories(id) from auth.users;
insert into public.profiles (user_id) select id from auth.users on conflict (user_id) do nothing;
