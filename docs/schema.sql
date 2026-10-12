-- ============================================================================
-- BIFFY DELIVERY PLATFORM - ESQUEMA DE BASE DE DATOS POSTGRESQL / SUPABASE
-- Compatible con PostgreSQL 15+ y Supabase con RLS y PostGIS
-- ============================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. Tipos Enumerados (Enums)
CREATE TYPE user_role_enum AS ENUM ('student', 'courier', 'merchant', 'admin');
CREATE TYPE order_status_enum AS ENUM ('programado', 'confirmado', 'preparando', 'en_camino', 'entregado', 'cancelado');
CREATE TYPE ticket_status_enum AS ENUM ('nuevo', 'preparando', 'listo', 'en_camino', 'entregado', 'rechazado');
CREATE TYPE payment_type_enum AS ENUM ('card', 'nequi', 'daviplata', 'pse', 'cash');
CREATE TYPE card_brand_enum AS ENUM ('visa', 'mastercard', 'amex', 'other');
CREATE TYPE vehicle_type_enum AS ENUM ('bicicleta', 'moto', 'pie');
CREATE TYPE merchant_status_enum AS ENUM ('pending', 'approved', 'suspended');

-- 3. Universidades y Puntos de Entrega Campus
CREATE TABLE IF NOT EXISTS universities (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    domain VARCHAR(100) NOT NULL UNIQUE,
    center_lat DOUBLE PRECISION NOT NULL,
    center_lng DOUBLE PRECISION NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_points (
    id VARCHAR(50) PRIMARY KEY,
    university_id VARCHAR(50) REFERENCES universities(id) ON DELETE SET NULL,
    name VARCHAR(120) NOT NULL,
    detail VARCHAR(255) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    location GEOMETRY(Point, 4326),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Actualizar automáticamente columna de geometría
CREATE OR REPLACE FUNCTION update_delivery_point_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_delivery_point_location
BEFORE INSERT OR UPDATE ON delivery_points
FOR EACH ROW EXECUTE FUNCTION update_delivery_point_location();

-- 4. Perfiles de Usuario (Extensión de auth.users)
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(30),
    full_name VARCHAR(150) NOT NULL,
    avatar_url TEXT,
    career VARCHAR(120),
    university_id VARCHAR(50) REFERENCES universities(id) ON DELETE SET NULL,
    is_student_verified BOOLEAN DEFAULT FALSE,
    current_role user_role_enum DEFAULT 'student',
    gotas_balance INTEGER DEFAULT 0 CHECK (gotas_balance >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
    likes TEXT[] DEFAULT '{}',
    allergies TEXT[] DEFAULT '{}',
    lifestyle TEXT[] DEFAULT '{}',
    budget_max DECIMAL(10,2) DEFAULT 25000,
    survey_completed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Restaurantes, Marcas y Sedes
CREATE TABLE IF NOT EXISTS merchant_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
    brand_name VARCHAR(120) NOT NULL,
    legal_name VARCHAR(180) NOT NULL,
    nit VARCHAR(30) NOT NULL,
    person_type VARCHAR(20) DEFAULT 'natural',
    cuisine_category VARCHAR(50) NOT NULL,
    description TEXT,
    logo_url TEXT,
    inc_responsible BOOLEAN DEFAULT FALSE,
    shows_nutrition BOOLEAN DEFAULT FALSE,
    status merchant_status_enum DEFAULT 'approved',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sedes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(80) DEFAULT 'Bogotá',
    phone VARCHAR(30) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    location GEOMETRY(Point, 4326),
    radius_km DECIMAL(3,1) DEFAULT 2.5,
    campus_id VARCHAR(50) REFERENCES universities(id) ON DELETE SET NULL,
    student_discount DECIMAL(3,2) DEFAULT 0.00,
    open_hour INTEGER DEFAULT 8 CHECK (open_hour >= 0 AND open_hour <= 23),
    close_hour INTEGER DEFAULT 21 CHECK (close_hour >= 0 AND close_hour <= 23),
    closed_days INTEGER[] DEFAULT '{}',
    is_paused BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_sede_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sede_location
BEFORE INSERT OR UPDATE ON sedes
FOR EACH ROW EXECUTE FUNCTION update_sede_location();

-- 6. Categorías, Platos y Opciones
CREATE TABLE IF NOT EXISTS categories (
    id VARCHAR(50) PRIMARY KEY,
    label VARCHAR(80) NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    display_order INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dishes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
    category_id VARCHAR(50) REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    section VARCHAR(80) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    emoji VARCHAR(10),
    prep_min INTEGER DEFAULT 15,
    calories INTEGER DEFAULT 0,
    nutrition_info JSONB,
    tags TEXT[] DEFAULT '{}',
    allergens TEXT[] DEFAULT '{}',
    photo_url TEXT,
    is_popular BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dish_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dish_id UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    group_name VARCHAR(80) DEFAULT 'Adiciones',
    label VARCHAR(120) NOT NULL,
    price DECIMAL(10,2) DEFAULT 0.00 CHECK (price >= 0),
    is_required BOOLEAN DEFAULT FALSE
);

-- 7. Métodos de Pago Guardados y Transacciones
CREATE TABLE IF NOT EXISTS payment_methods (
    id VARCHAR(80) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    type payment_type_enum NOT NULL,
    card_brand card_brand_enum,
    last4 VARCHAR(4),
    cardholder_name VARCHAR(120),
    exp_month VARCHAR(2),
    exp_year VARCHAR(4),
    gateway_token TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Pedidos e Ítems
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(20) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
    delivery_point_id VARCHAR(50) NOT NULL REFERENCES delivery_points(id) ON DELETE RESTRICT,
    subtotal DECIMAL(10,2) NOT NULL,
    student_discount DECIMAL(10,2) DEFAULT 0.00,
    delivery_fee DECIMAL(10,2) NOT NULL,
    points_discount DECIMAL(10,2) DEFAULT 0.00,
    points_used INTEGER DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    status order_status_enum DEFAULT 'confirmado',
    payment_method_id VARCHAR(80) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'paid',
    client_security_code VARCHAR(4) NOT NULL,
    scheduled_for TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id VARCHAR(20) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    dish_id UUID NOT NULL REFERENCES dishes(id) ON DELETE RESTRICT,
    sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    notes TEXT,
    selected_options JSONB DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS merchant_tickets (
    id VARCHAR(30) PRIMARY KEY,
    order_id VARCHAR(20) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
    status ticket_status_enum DEFAULT 'nuevo',
    reject_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    ready_at TIMESTAMPTZ
);

-- 9. Repartidores y Asignaciones
CREATE TABLE IF NOT EXISTS courier_profiles (
    id UUID PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
    vehicle_type vehicle_type_enum DEFAULT 'bicicleta',
    preferred_zone VARCHAR(20) DEFAULT 'general',
    is_online BOOLEAN DEFAULT FALSE,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    current_location GEOMETRY(Point, 4326),
    rating_average DECIMAL(3,2) DEFAULT 5.00,
    total_rides INTEGER DEFAULT 0,
    pending_fee DECIMAL(10,2) DEFAULT 0.00,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id VARCHAR(20) UNIQUE NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    courier_id UUID NOT NULL REFERENCES courier_profiles(id) ON DELETE RESTRICT,
    pickup_code VARCHAR(4) NOT NULL,
    courier_earnings DECIMAL(10,2) NOT NULL,
    proof_photo_url TEXT,
    status VARCHAR(30) DEFAULT 'assigned',
    accepted_at TIMESTAMPTZ DEFAULT NOW(),
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ
);

-- 10. Ledger de Gotas (Puntos de Fidelización)
CREATE TABLE IF NOT EXISTS gotas_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reason VARCHAR(255) NOT NULL,
    order_id VARCHAR(20) REFERENCES orders(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Índices para Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_sedes_location ON sedes USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_delivery_points_location ON delivery_points USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_courier_location ON courier_profiles USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_merchant_tickets_sede ON merchant_tickets(sede_id, status);
CREATE INDEX IF NOT EXISTS idx_dishes_category ON dishes(category_id);
CREATE INDEX IF NOT EXISTS idx_dishes_merchant ON dishes(merchant_id);

-- ============================================================================
-- SEED DATA INICIAL
-- ============================================================================

INSERT INTO universities (id, name, domain, center_lat, center_lng)
VALUES 
    ('unal', 'Universidad Nacional de Colombia', 'unal.edu.co', 4.6366, -74.0822),
    ('andes', 'Universidad de los Andes', 'uniandes.edu.co', 4.6020, -74.0660),
    ('javeriana', 'Pontificia Universidad Javeriana', 'javeriana.edu.co', 4.6290, -74.0645)
ON CONFLICT (id) DO NOTHING;

INSERT INTO delivery_points (id, university_id, name, detail, lat, lng)
VALUES 
    ('biblio', 'unal', 'Biblioteca Central', 'Entrada principal', 4.6355, -74.0830),
    ('inge', 'unal', 'Edificio Ingeniería', 'Hall piso 1', 4.6378, -74.0825),
    ('plazoleta', 'unal', 'Plazoleta Che', 'Junto a las bancas', 4.6362, -74.0815),
    ('chapinero', NULL, 'Casa · Chapinero', 'Cra 7 #60-20', 4.6465, -74.0628),
    ('suba', NULL, 'Casa · Suba', 'Cl 145 #91-10', 4.7405, -74.0835)
ON CONFLICT (id) DO NOTHING;

INSERT INTO categories (id, label, emoji, display_order)
VALUES 
    ('pizza', 'Pizza', '🍕', 1),
    ('hamburguesa', 'Hamburguesas', '🍔', 2),
    ('saludable', 'Saludable', '🥗', 3),
    ('almuerzo', 'Almuerzos', '🍛', 4),
    ('cafe', 'Café', '☕', 5),
    ('postres', 'Postres', '🍩', 6),
    ('mexicana', 'Mexicana', '🌮', 7),
    ('asiatica', 'Asiática', '🍜', 8)
ON CONFLICT (id) DO NOTHING;
