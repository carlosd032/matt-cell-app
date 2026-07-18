-- ============================================================
-- MATT CELL — esquema Supabase (proyecto independiente de güao)
-- Ejecutar completo en: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Perfiles de usuario (uno por cada admin/vendedor que inicie sesión)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  nombre text,
  rol text not null default 'vendedor' check (rol in ('dueño','vendedor')),
  created_at timestamptz default now()
);

-- Clientes
create table if not exists clientes (
  key text primary key,
  nombre text not null,
  id_cliente text default '',
  direccion text default '',
  telefono text default '',
  created_at timestamptz default now()
);

-- Ventas (incluye el objeto de crédito completo como JSON: cuotas, frecuencia, pagos, abono inicial)
create table if not exists ventas (
  id bigint primary key,
  fecha date,
  cliente_key text references clientes(key),
  cliente text,
  tipo_producto text default 'CELULAR',
  marca text default '',
  modelo text,
  capacidad text default '',
  color text default '',
  condicion text default 'NUEVO',
  imei text default '',
  proveedor text default '',
  metodo_pago text default 'EFECTIVO',
  costo_cop numeric default 0,
  pvp numeric default 0,
  utilidad numeric default 0,
  tipo_pago text default 'CONTADO',
  credito jsonb,
  updated_at timestamptz
);

-- Inventario
create table if not exists inventario (
  id bigint primary key,
  fecha_compra date,
  marca text default '',
  modelo text,
  capacidad text default '',
  color text default '',
  condicion text default 'NUEVO',
  imei text default '',
  proveedor text default '',
  cantidad int default 1,
  costo_cop numeric default 0,
  valor_venta numeric default 0,
  vendido boolean default false,
  fecha_venta date
);

-- Gastos operativos
create table if not exists gastos (
  id bigint primary key,
  fecha date,
  categoria text,
  descripcion text,
  monto numeric default 0
);

-- Capital inicial (fila única de configuración)
create table if not exists capital_inicial (
  id int primary key default 1,
  monto numeric default 0,
  fecha date,
  constraint single_row check (id = 1)
);
insert into capital_inicial (id, monto, fecha) values (1, 0, current_date)
  on conflict (id) do nothing;

-- Si la tabla ventas ya existía sin esta columna (actualización), agrégala:
alter table ventas add column if not exists tipo_producto text default 'CELULAR';
alter table obligaciones add column if not exists frecuencia text default 'MENSUAL';

-- Inyecciones de capital adicionales
create table if not exists capital_inyectado (
  id bigint primary key,
  fecha date,
  descripcion text,
  monto numeric default 0
);

-- Obligaciones bancarias (gastos fijos: préstamos, tarjetas, leasing, arriendos)
create table if not exists obligaciones (
  id bigint primary key,
  entidad text not null,
  tipo text default 'Préstamo',
  monto_cuota numeric default 0,
  dia_pago int default 1,
  fecha_inicio date,
  cuotas_totales int default 0,
  activa boolean default true
);

-- ============================================================
-- Seguridad: Row Level Security
-- Regla: cualquier usuario CON SESIÓN (login exitoso) puede leer/escribir
-- todos los datos del negocio (es una app interna multiusuario, no pública).
-- ============================================================
alter table profiles enable row level security;
alter table clientes enable row level security;
alter table ventas enable row level security;
alter table inventario enable row level security;
alter table gastos enable row level security;
alter table capital_inicial enable row level security;
alter table capital_inyectado enable row level security;
alter table obligaciones enable row level security;

-- Si ya habías corrido una versión anterior de este script, elimina las políticas
-- viejas (permisivas) antes de crear las nuevas restringidas por rol:
drop policy if exists "usuarios autenticados ven su perfil" on profiles;
drop policy if exists "usuarios autenticados actualizan su perfil" on profiles;
drop policy if exists "usuarios autenticados crean su perfil" on profiles;
drop policy if exists "auth full access clientes" on clientes;
drop policy if exists "auth full access ventas" on ventas;
drop policy if exists "auth full access inventario" on inventario;
drop policy if exists "auth full access gastos" on gastos;
drop policy if exists "auth full access capital_inicial" on capital_inicial;
drop policy if exists "auth full access capital_inyectado" on capital_inyectado;
drop policy if exists "auth full access obligaciones" on obligaciones;
drop policy if exists "usuarios autenticados ven su perfil" on profiles;
drop policy if exists "usuarios autenticados actualizan su perfil" on profiles;
drop policy if exists "usuarios autenticados crean su perfil" on profiles;
drop policy if exists "clientes select" on clientes;
drop policy if exists "clientes insert" on clientes;
drop policy if exists "clientes update" on clientes;
drop policy if exists "clientes delete solo dueño" on clientes;
drop policy if exists "ventas select" on ventas;
drop policy if exists "ventas insert" on ventas;
drop policy if exists "ventas update" on ventas;
drop policy if exists "ventas delete solo dueño" on ventas;
drop policy if exists "inventario select" on inventario;
drop policy if exists "inventario insert" on inventario;
drop policy if exists "inventario update" on inventario;
drop policy if exists "inventario delete solo dueño" on inventario;
drop policy if exists "gastos solo dueño" on gastos;
drop policy if exists "capital_inicial solo dueño" on capital_inicial;
drop policy if exists "capital_inyectado solo dueño" on capital_inyectado;
drop policy if exists "obligaciones solo dueño" on obligaciones;

-- Regla base: cualquier usuario CON SESIÓN puede leer/crear/editar.
-- Reglas reforzadas: SOLO 'dueño' puede eliminar registros de negocio,
-- y SOLO 'dueño' puede tocar las tablas contables (gastos, capital, obligaciones).
create or replace function is_dueño()
returns boolean language sql stable as $$
  select exists(select 1 from profiles where id = auth.uid() and rol = 'dueño');
$$;

create policy "usuarios autenticados ven su perfil" on profiles
  for select using (auth.uid() = id);
create policy "usuarios autenticados actualizan su perfil" on profiles
  for update using (auth.uid() = id);
create policy "usuarios autenticados crean su perfil" on profiles
  for insert with check (auth.uid() = id);

create policy "clientes select" on clientes for select using (auth.uid() is not null);
create policy "clientes insert" on clientes for insert with check (auth.uid() is not null);
create policy "clientes update" on clientes for update using (auth.uid() is not null);
create policy "clientes delete solo dueño" on clientes for delete using (is_dueño());

create policy "ventas select" on ventas for select using (auth.uid() is not null);
create policy "ventas insert" on ventas for insert with check (auth.uid() is not null);
create policy "ventas update" on ventas for update using (auth.uid() is not null);
create policy "ventas delete solo dueño" on ventas for delete using (is_dueño());

create policy "inventario select" on inventario for select using (auth.uid() is not null);
create policy "inventario insert" on inventario for insert with check (auth.uid() is not null);
create policy "inventario update" on inventario for update using (auth.uid() is not null);
create policy "inventario delete solo dueño" on inventario for delete using (is_dueño());

create policy "gastos solo dueño" on gastos for all using (is_dueño()) with check (is_dueño());
create policy "capital_inicial solo dueño" on capital_inicial for all using (is_dueño()) with check (is_dueño());
create policy "capital_inyectado solo dueño" on capital_inyectado for all using (is_dueño()) with check (is_dueño());
create policy "obligaciones solo dueño" on obligaciones for all using (is_dueño()) with check (is_dueño());

-- ============================================================
-- Después de correr esto:
-- 1. Ve a Authentication → Users → "Add user" para crear cada administrador
--    (dueño y vendedores), con su email y contraseña.
-- 2. Por cada usuario creado, inserta su fila en profiles, por ejemplo:
--    insert into profiles (id, email, nombre, rol)
--    values ('<uuid-del-usuario>', 'correo@ejemplo.com', 'Nombre', 'dueño');
--    (el uuid lo copias de Authentication → Users)
-- ============================================================
