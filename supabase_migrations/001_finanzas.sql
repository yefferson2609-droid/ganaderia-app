-- Módulo Finanzas: tablas + RLS
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

create table if not exists conceptos_financieros (
  id uuid primary key,
  nombre text not null,
  tipo text not null check (tipo in ('ingreso', 'gasto')),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists movimientos_financieros (
  id uuid primary key,
  tipo text not null check (tipo in ('ingreso', 'gasto')),
  concepto_id uuid references conceptos_financieros(id),
  nota text,
  monto numeric(14, 2) not null check (monto > 0),
  fecha date not null,
  ubicacion_id uuid references ubicaciones(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table conceptos_financieros enable row level security;
alter table movimientos_financieros enable row level security;

-- Mismo criterio que el resto de tablas de la app: cualquier usuario
-- autenticado puede leer y escribir (no hay permisos granulares todavía;
-- eso llega en la fase de Usuarios/Permisos).
create policy "authenticated_all_conceptos_financieros"
  on conceptos_financieros for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "authenticated_all_movimientos_financieros"
  on movimientos_financieros for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');
