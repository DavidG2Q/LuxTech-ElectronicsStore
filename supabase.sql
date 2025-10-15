---------| Delete Everything (Users , Tables, functions , triggers, Policies)| ---------
DO $$
DECLARE
    r RECORD;
BEGIN
    -- DROP ALL TRIGGERS
    FOR r IN
        SELECT event_object_table, trigger_name
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON public.%I CASCADE;',
            r.trigger_name,
            r.event_object_table
        );
    END LOOP;

------------------

    -- DROP ALL USER TABLES (excluding Supabase/auth system tables)
    FOR r IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename NOT IN ('schema_migrations')
          AND tablename NOT LIKE 'pg_%'
          AND tablename NOT LIKE 'sql_%'
          AND tablename NOT LIKE 'auth%'
          AND tablename NOT LIKE '_prisma%'
    LOOP
        EXECUTE format(
            'DROP TABLE IF EXISTS public.%I CASCADE;',
            r.tablename
        );
    END LOOP;

-------------------

    ---| DROP ALL FUNCTIONS (user-defined only) |---------
    FOR r IN
        SELECT proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    LOOP
        EXECUTE format(
            'DROP FUNCTION IF EXISTS public.%I(%s) CASCADE;',
            r.proname,
            r.args
        );
    END LOOP;
END $$;

------------------

-----------| Deletes all users from auth.users using the Supabase admin function |---------
 DELETE FROM auth.users
 WHERE true;
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--------------------Create all Required Tables , Policies , Triggers , Functions---------------------------
-- PostgreSQL Configuration Settings
SET statement_timeout = 0;                    -- Disable query timeout (queries can run indefinitely)
SET lock_timeout = 0;                         -- Disable lock timeout (no waiting for locks)
SET idle_in_transaction_session_timeout = 0;  -- Disable idle session timeout
SET client_encoding = 'UTF8';                 -- Set character encoding to UTF-8 for international support
SET standard_conforming_strings = on;         -- Enable standard SQL string literal behavior
SELECT pg_catalog.set_config('search_path', '', false);  -- Clear search path for security
SET check_function_bodies = false;            -- Don't validate function bodies during creation
SET xmloption = content;                      -- Set XML parsing option
SET client_min_messages = warning;            -- Only show warning and error messages
SET row_security = off;                       -- Temporarily disable RLS during setup

-- Install Required PostgreSQL Extensions
CREATE EXTENSION IF NOT EXISTS "pgsodium";           -- Encryption and security functions
COMMENT ON SCHEMA "public" IS 'standard public schema';
CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";        -- GraphQL API support
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";  -- Query performance monitoring
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";       -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";          -- JWT token handling
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";      -- Secure secret storage
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";      -- UUID generation functions

-- Database Storage Configuration
SET default_tablespace = '';                 -- Use default tablespace
SET default_table_access_method = "heap";    -- Use heap storage method for tables

-- Create Category Table (for product categorization)
CREATE TABLE IF NOT EXISTS "public"."category" (
    "id" uuid PRIMARY KEY,
    "category_name" text NOT NULL,
    "subcategory_name" text
);

ALTER TABLE "public"."category" OWNER TO "postgres";

-- Insert Categories and Subcategories
INSERT INTO public.category (id, category_name, subcategory_name) VALUES
  ('00000000-0000-0000-0000-00000000C001', 'Smartphones', 'Iphone'),
  ('00000000-0000-0000-0000-00000000C002', 'Smartphones', 'Samsung'),
  ('00000000-0000-0000-0000-00000000C003', 'Laptops', 'Business Laptops'),
  ('00000000-0000-0000-0000-00000000C004', 'Laptops', 'Gaming Laptops'),
  ('00000000-0000-0000-0000-00000000C005', 'iPad', NULL),
  ('00000000-0000-0000-0000-00000000C006', 'Watch', 'Apple Watch'),
  ('00000000-0000-0000-0000-00000000C007', 'AirPods', 'AirPods Pro'),
  ('00000000-0000-0000-0000-00000000C008', 'AirPods', 'AirPods Max'),
  ('00000000-0000-0000-0000-00000000C009', 'TV', 'Apple TV'),
  ('00000000-0000-0000-0000-00000000C010', 'TV', 'Smart TV'),
  ('00000000-0000-0000-0000-00000000C011', 'TV', 'Samsung TV'),
  ('00000000-0000-0000-0000-00000000C012', 'Watch', 'Samsung Watch'),
  ('00000000-0000-0000-0000-00000000C013', 'iPad', 'iPad Pro'),
  ('00000000-0000-0000-0000-00000000C014', 'iPad', 'iPad Air'),
  ('00000000-0000-0000-0000-00000000C015', 'iPad', 'iPad Mini');

-- Enable RLS on category table
ALTER TABLE "public"."category" ENABLE ROW LEVEL SECURITY;

-- Allow anonymous and authenticated users to read categories
CREATE POLICY "Allow anonymous read categories" ON "public"."category" FOR SELECT TO "anon" USING (true);
CREATE POLICY "Allow authenticated read categories" ON "public"."category" FOR SELECT TO "authenticated" USING (true);

--Create table Prodcuts
CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "price" numeric NOT NULL,
    "image_url" "text",
    "description" "text",
    "category_id" uuid,
    "colors" "jsonb",
    "variants" "jsonb",
    "is_featured" boolean DEFAULT false,
    "is_new" boolean DEFAULT false,
    "specifications" "jsonb"
);

ALTER TABLE "public"."products" OWNER TO "postgres";

--Create table Profiles
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "email" "text",
    "street" "text",
    "building" "text",
    "city" "text",
    "phone" "text"
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Add foreign key constraint after both tables exist
ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."category"("id");

CREATE POLICY "Allow authenticated delete" ON "public"."products" FOR DELETE TO "authenticated" USING (true);
CREATE POLICY "Allow authenticated insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK (true);
CREATE POLICY "Allow authenticated read" ON "public"."products" FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "Allow authenticated update" ON "public"."products" FOR UPDATE TO "authenticated" USING (true);

-- Allow anonymous users to browse products (read-only)
CREATE POLICY "Allow anonymous read" ON "public"."products" FOR SELECT TO "anon" USING (true);

CREATE POLICY "Enable insert for users only" ON "public"."profiles" FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update their own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));
CREATE POLICY "Users can view their own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));

ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";
ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."products";
ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."profiles";

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
------------------------------------------------------------------------------------------------------------------------

--------------------Grant admin role to admin@admin.com------------------------------------
DO $$
DECLARE
    admin_id uuid;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_id FROM auth.users WHERE email = 'admin@admin.com';

    -- Grant admin role
    UPDATE auth.users
    SET role = 'authenticated'
    WHERE id = admin_id;

    -- Ensure admin has access to products table
    GRANT ALL ON TABLE public.products TO authenticated;
    
    -- Refresh RLS policies for products table
    ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
    
    -- Drop existing policies if any
    DROP POLICY IF EXISTS "Allow authenticated insert" ON public.products;
    DROP POLICY IF EXISTS "Allow authenticated delete" ON public.products;
    DROP POLICY IF EXISTS "Allow authenticated read" ON public.products;
    DROP POLICY IF EXISTS "Allow authenticated update" ON public.products;
    
    -- Create new policies
    CREATE POLICY "Allow authenticated insert" ON public.products
        FOR INSERT TO authenticated
        WITH CHECK (true);
    
    CREATE POLICY "Allow authenticated delete" ON public.products
        FOR DELETE TO authenticated
        USING (true);
    
    CREATE POLICY "Allow authenticated read" ON public.products
        FOR SELECT TO authenticated
        USING (true);
    
    CREATE POLICY "Allow authenticated update" ON public.products
        FOR UPDATE TO authenticated
        USING (true);
END $$;
----------------------------------------------------------------------------------------------------

----------------------| Save each User's info TO Profiles table| --------------------------- 
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    -- Insert into profiles using the name from registration metadata
    INSERT INTO public.profiles (
        id,
        name,
        email,
        street,
        building,
        city,
        phone
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),  -- Use name from registration metadata or default to 'User'
        NEW.email,
        NEW.raw_user_meta_data->>'street',
        NEW.raw_user_meta_data->>'building',
        NEW.raw_user_meta_data->>'city',
        NEW.raw_user_meta_data->>'phone'
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in handle_new_user: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--------------------------------------------------------------------------------------------------------------------------

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;

-- Create the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
------------------------------------------------------------------------------------------------------------------------

---Clean everyhting after reseting above
RESET ALL;

------------------------------------------------------------------------------------------------------------------------
-- Create orders table
CREATE TABLE "public"."orders" (
    "id" TEXT PRIMARY KEY,  --existing order ID format
    "user_id" UUID NOT NULL,  -- Same UUID from auth.users
    "TotalOrderPrice" DECIMAL(10,2) NOT NULL,
    "subtotal" INTEGER NOT NULL DEFAULT 0,
    "taxes" INTEGER NOT NULL DEFAULT 0,
    "order_date" TIMESTAMP WITH TIME ZONE NOT NULL,
    "status" TEXT NOT NULL CHECK (status IN (
        'Being Processed',
        'Shipped',
        'Delivered',
        'Return Requested',
        'Received by Courier',
        'Being Inspected',
        'Accepted Return',
        'Returned',
        'Cancelled'
    )),
    "delivery_fee" TEXT,
    "OrderRating" INTEGER DEFAULT 0 CHECK ("OrderRating" >= 0 AND "OrderRating" <= 5),
    "return_reason" TEXT,
    "return_bank_acc" TEXT
);

-- Create order_items table (without foreign key constraints initially)
CREATE TABLE "public"."order_items" (
    "id" TEXT PRIMARY KEY,  -- Your existing order item ID format
    "order_id" TEXT NOT NULL,
    "product_id" UUID NOT NULL, 
    "name" TEXT NOT NULL,
    "TotalProductPrice" DECIMAL(10,2) NOT NULL,
    "TotalProductQty" INTEGER NOT NULL,
    "color" TEXT,
    "variant" TEXT
);

-- Add foreign key constraints after tables are created
ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "fk_user_auth" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "fk_order" FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    ADD CONSTRAINT "fk_product" FOREIGN KEY (product_id) REFERENCES products(id);

-- Enable RLS
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;

-- Orders policies
CREATE POLICY "Users can view their own orders"
    ON "public"."orders"
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own orders"
    ON "public"."orders"
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own orders"
    ON "public"."orders"
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Order items policies
CREATE POLICY "Users can view their own order items"
    ON "public"."order_items"
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    ));

CREATE POLICY "Users can insert their own order items"
    ON "public"."order_items"
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own order items"
    ON "public"."order_items"
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    ));

-- Orders indexes
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(order_date);

-- Order items indexes
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Add tables to realtime publication
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."orders";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."order_items";

-- Create function to populate order_item details from products
CREATE OR REPLACE FUNCTION populate_order_item_details()
RETURNS TRIGGER AS $$
BEGIN
    SELECT p.name, p.price
    INTO NEW.name, NEW.TotalProductPrice
    FROM public.products AS p
    WHERE p.id = NEW.product_id;

    IF NEW.name IS NULL THEN
        RAISE EXCEPTION 'Product with ID % not found.', NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run populate_order_item_details before insert on order_items
CREATE TRIGGER trigger_populate_order_item_details
BEFORE INSERT ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION populate_order_item_details();

-- Trigger function to sync product price and first variant price
CREATE OR REPLACE FUNCTION sync_product_price()
RETURNS TRIGGER AS $$
DECLARE
  new_variants jsonb;
  first_variant jsonb;
  updated_variants jsonb;
  new_price numeric;
BEGIN
  new_variants := NEW.variants;
  -- If the price field changed, update the first variant's price
  IF NEW.price IS DISTINCT FROM OLD.price THEN
    IF jsonb_array_length(new_variants) > 0 THEN
      first_variant := new_variants->0;
      -- Replace the price in the first variant
      first_variant := jsonb_set(first_variant, '{price}', to_jsonb(NEW.price));
      -- Replace the first element in the array
      updated_variants := jsonb_set(new_variants, '{0}', first_variant);
      NEW.variants := updated_variants;
    END IF;
  END IF;

  -- If the first variant's price changed, update the product price
  IF jsonb_array_length(new_variants) > 0 THEN
    new_price := (new_variants->0->>'price')::numeric;
    IF new_price IS DISTINCT FROM OLD.price THEN
      NEW.price := new_price;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the sync function before update on products
DROP TRIGGER IF EXISTS trg_sync_product_price ON public.products;
CREATE TRIGGER trg_sync_product_price
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION sync_product_price();

-- Create payment table connected to orders
CREATE TABLE "public"."payment" (
    "PaymentId" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "order_id" TEXT NOT NULL,
    "PaymentMethod" TEXT NOT NULL,
    "PaymentDetails" TEXT,
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX idx_payment_order_id ON payment(order_id);

ALTER TABLE "public"."payment" ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own payment records
CREATE POLICY "Users can view their own payments"
    ON "public"."payment"
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = payment.order_id
        AND orders.user_id = auth.uid()
    ));

-- Allow users to insert their own payment records
CREATE POLICY "Users can insert their own payments"
    ON "public"."payment"
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = payment.order_id
        AND orders.user_id = auth.uid()
    ));

---------------------------------------------------------------------------------------------------
-------------------------| Products data insertion |
INSERT INTO public.products (id, name, price, image_url, description, category_id, colors, variants, is_featured, is_new, specifications) 
VALUES 
('00000000-0000-0000-0000-000000000001', 'Iphone 15 Pro', 47073, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/phones/Iphone15Pro.jpeg', 'Titanium. Strong. Light. Pro.', '00000000-0000-0000-0000-00000000C001', 
 '[{"name": "titanium Natural", "colorCode": "0xFFE3D0BA"}, {"name": "titanium Blue", "colorCode": "0xFF7D9AAA"}, {"name": "titanium White", "colorCode": "0xFFF5F5F0"}, {"name": "titanium black", "colorCode": "0xFF4D4D4D"}]',
 '[{"name": "128GB", "price": 47073, "quantity": 10}, {"name": "256GB", "price": 51785, "quantity": 8}, {"name": "512GB", "price": 61209, "quantity": 5}, {"name": "1TB", "price": 70633, "quantity": 2}]',
 true, true,
 '["6.7-inch Super Retina XDR display", "Titanium design - lighter and stronger", "A17 Pro chip - exceptional performance", "Pro 48MP triple camera system", "Customizable Action button", "All-day battery life", "USB-C with high data transfer speeds", "iOS 17"]'),

('00000000-0000-0000-0000-000000000002', 'MacBook Air', 65945, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/laptops/MacbookAir.jpeg', 'Equipped with M2 chip. Lightweight. Powerful performance.', '00000000-0000-0000-0000-00000000C003',
 '[{"name": "space gray", "colorCode": "0xFF4A4A4A"}, {"name": "silver", "colorCode": "0xFFE3E3E3"}, {"name": "gold", "colorCode": "0xFFE8D0B8"}, {"name": "Midnight", "colorCode": "0xFF1E1E1E"}]',
 '[{"name": "8GB / 256GB", "price": 65945, "quantity": 7}, {"name": "8GB / 512GB", "price": 76945, "quantity": 4}, {"name": "16GB / 512GB", "price": 87945, "quantity": 3}, {"name": "16GB / 1TB", "price": 98945, "quantity": 1}]',
 true, false,
 '["Apple M2 chip", "13.6-inch Liquid Retina display", "Unified memory up to 16GB", "SSD storage up to 1TB", "1080p FaceTime HD camera", "Quad-speaker sound system", "Up to 18 hours of battery life", "Two Thunderbolt / USB 4 ports"]'),

('00000000-0000-0000-0000-000000000003', 'iPad Pro', 43945, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/Ipad/Ipad%20pro.jpg', 'Powerful tablet in a sleek design.', '00000000-0000-0000-0000-00000000C005',
 '[{"name": "silver", "colorCode": "0xFFE3E3E3"}, {"name": "space gray", "colorCode": "0xFF4A4A4A"}]',
 '[{"name": "11 inch - 128GB", "price": 43945, "quantity": 6}, {"name": "11 inch - 256GB", "price": 49445, "quantity": 4}, {"name": "12.9 inch - 128GB", "price": 3324475, "quantity": 2}, {"name": "12.9 inch - 256GB", "price": 65945, "quantity": 1}]',
 true, false,
 '["Apple M2 chip", "Liquid Retina XDR display", "12MP rear camera + LiDAR", "12MP front camera", "Storage up to 2TB", "Compatible with Apple Pencil and Magic Keyboard", "USB-C port", "Face ID"]'),

('00000000-0000-0000-0000-000000000004', 'Apple Watch Series 9', 23825, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/watches/Apple%20Watch%20Series%209.jpg', 'The most advanced and powerful watch yet.', '00000000-0000-0000-0000-00000000C006',
 '[{"name": "aluminium black", "colorCode": "0xFF1D1D1D"}, {"name": "aluminium silver", "colorCode": "0xFFE3E3E3"}, {"name": "aluminium gold", "colorCode": "0xFFE8D0B8"}, {"name": "Stainless Steel", "colorCode": "0xFFB8B8B8"}]',
 '[{"name": "41mm GPS", "price": 23825, "quantity": 10}, {"name": "45mm GPS", "price": 27500, "quantity": 7}, {"name": "41mm GPS + Cellular", "price": 28650, "quantity": 5}, {"name": "45mm GPS + Cellular", "price": 29750, "quantity": 2}]',
 true, false,
 '["Always-On Retina display", "S9 SiP chip", "Water-resistant up to 50 meters", "Blood oxygen sensor", "Electrocardiogram (ECG)", "Heart rate notifications", "Sleep tracking", "Fall and crash detection"]'),

('00000000-0000-0000-0000-000000000005', 'AirPods Pro', 13695, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/WirelessEarphones/AirpodsPro.jpeg', 'Active noise cancellation. Transparency mode. Spatial audio.', '00000000-0000-0000-0000-00000000C007',
 '[{"name": "White", "colorCode": "0xFFFFFFFF"}]',
 '[{"name": "AirPods Pro", "price": 13695, "quantity": 15}]',
 true, false,
 '["Active noise cancellation", "Transparency mode", "Spatial audio with head tracking", "Water and sweat resistant", "H2 chip", "Up to 6 hours of battery life", "MagSafe charging", "High-fidelity dynamic drivers"]'),

('00000000-0000-0000-0000-000000000006', 'AirPods Max', 36456, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/WirelessEarphones/AirpodsMax.png', 'High-fidelity audio. Active noise cancellation. Spatial audio.', '00000000-0000-0000-0000-00000000C008',
 '[{"name": "silver", "colorCode": "0xFFE3E3E3"}, {"name": "black", "colorCode": "0xFF1D1D1D"}, {"name": "sky Blue ", "colorCode": "0xFF76AECE"}, {"name": "pink", "colorCode": "0xFFE5C0C0"}, {"name": "green", "colorCode": "0xFF8FBC94"}]',
 '[{"name": "AirPods Max", "price": 36456, "quantity": 8}]',
 true, false,
 '["Active noise cancellation", "Transparency mode", "Spatial audio", "H1 chip", "Battery life up to 20 hours", "Comfortable design", "Exceptional sound quality", "Digital crown control"]'),

('00000000-0000-0000-0000-000000000007', 'Apple TV 4K', 8600, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/SmartTvs/AppleTv.jpeg', 'Amazing viewing experience. Great apps. Smart home control.', '00000000-0000-0000-0000-00000000C009',
 '[{"name": "black", "colorCode": "0xFF1D1D1D"}]',
 '[{"name": "64GB", "price": 8600, "quantity": 12}, {"name": "128GB", "price": 15000, "quantity": 6}]',
 true, false,
 '["4K HDR resolution with Dolby Vision", "A15 Bionic chip", "Siri Remote", "Dolby Atmos support", "Apple TV+", "Apple Arcade", "Apple Fitness+", "Home control"]'),

('00000000-0000-0000-0000-000000000008', 'Iphone 14', 88629, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/phones/Iphone14.jpg', 'Incredible power and performance with a sleek design.', '00000000-0000-0000-0000-00000000C001',
 '[{"name": "Blue", "colorCode": "0xFF7D9AAA"}, {"name": "red", "colorCode": "0xFFFF4D4D"}, {"name": "White", "colorCode": "0xFFF5F5F0"}, {"name": "black", "colorCode": "0xFF4D4D4D"}]',
 '[{"name": "128GB", "price": 88629, "quantity": 9}, {"name": "256GB", "price": 93871, "quantity": 6}, {"name": "512GB", "price": 104354, "quantity": 3}]',
 true, false,
 '["6.1-inch Super Retina XDR display", "A15 Bionic chip with 5-core GPU", "Advanced 12MP dual camera system", "Cinematic mode and night photography", "Water and dust resistant", "All-day battery life", "Face ID for biometric security", "iOS 16"]'),

('00000000-0000-0000-0000-000000000009', 'Samsung Galaxy S23 Ultra', 65945, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/phones/s23u.jpg', 'Advanced smartphone with S Pen and 200MP camera.', '00000000-0000-0000-0000-00000000C002',
 '[{"name": "phantom black", "colorCode": "0xFF000000"}, {"name": "Cream", "colorCode": "0xFFF5F5DC"}, {"name": "green", "colorCode": "0xFF2E8B57"}, {"name": "purple", "colorCode": "0xFF9370DB"}]',
 '[{"name": "256GB", "price": 65945, "quantity": 8}, {"name": "512GB", "price": 75845, "quantity": 5}, {"name": "1TB", "price": 89045, "quantity": 2}]',
 true, true,
 '["6.8-inch Dynamic AMOLED 2X display", "Snapdragon 8 Gen 2 processor", "200MP main camera", "Integrated S Pen", "5000mAh battery", "45W fast charging", "IP68 water and dust resistant", "Android 13 with One UI 5.1"]'),

('00000000-0000-0000-0000-000000000010', 'Samsung Galaxy Z Fold 5', 98945, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/phones/Zfold5.webp', 'Foldable phone with a dual display and exceptional performance.', '00000000-0000-0000-0000-00000000C002',
 '[{"name": "black", "colorCode": "0xFF000000"}, {"name": "Cream", "colorCode": "0xFFF5F5DC"}, {"name": "Blue", "colorCode": "0xFF0000FF"}]',
 '[{"name": "256GB", "price": 98945, "quantity": 4}, {"name": "512GB", "price": 105545, "quantity": 2}, {"name": "1TB", "price": 118745, "quantity": 1}]',
 true, false,
 '["7.6-inch foldable main display", "6.2-inch external display", "Snapdragon 8 Gen 2 processor", "50MP triple camera", "12GB RAM", "4400mAh battery", "S Pen support", "Android 13 with One UI 5.1.1"]'),

('00000000-0000-0000-0000-000000000011', 'MacBook Pro 16', 137445, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/laptops/Macbook16Pro.jpeg', 'MacBook Pro with M2 Pro or M2 Max chip. Massive power for professionals.', '00000000-0000-0000-0000-00000000C003',
 '[{"name": "Space Gray", "colorCode": "0xFF4A4A4A"}, {"name": "silver", "colorCode": "0xFFE3E3E3"}]',
 '[{"name": "M2 Pro / 16GB / 512GB", "price": 137445, "quantity": 5}, {"name": "M2 Pro / 16GB / 1TB", "price": 148445, "quantity": 3}, {"name": "M2 Max / 32GB / 1TB", "price": 192445, "quantity": 2}, {"name": "M2 Max / 64GB / 2TB", "price": 236445, "quantity": 1}]',
 true, false,
 '["M2 Pro or M2 Max chip", "16.2-inch Liquid Retina XDR display", "Unified memory up to 96GB", "SSD storage up to 8TB", "1080p FaceTime HD camera", "Six-speaker sound system", "Up to 22 hours of battery life", "Thunderbolt 4 ports, HDMI, and SD card reader"]'),

('00000000-0000-0000-0000-000000000012', 'Lenovo Legion Pro 7', 126445, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/laptops/Legion%20Pro%207.jpg', 'Gaming laptop with exceptional performance and advanced cooling.', '00000000-0000-0000-0000-00000000C004',
 '[{"name": "black", "colorCode": "0xFF000000"}]',
 '[{"name": "i9 / RTX 4080 / 32GB / 1TB", "price": 126445, "quantity": 3}, {"name": "i9 / RTX 4080 / 32GB / 2TB", "price": 137445, "quantity": 2}, {"name": "i9 / RTX 4090 / 64GB / 2TB", "price": 164945, "quantity": 1}]',
 true, false,
 '["Intel Core i9-13900HX processor", "NVIDIA GeForce RTX 4080/4090 graphics card", "16-inch display with 240Hz refresh rate", "DDR5 RAM up to 64GB", "PCIe Gen4 SSD storage up to 2TB", "Legion Coldfront 4.0 cooling system", "RGB backlit keyboard", "99.9Wh battery"]'),

('00000000-0000-0000-0000-000000000013', 'Lenovo Legion Slim 5', 82445, 'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/laptops/Legion%20slim%205.webp', 'Lightweight gaming laptop with powerful performance.', '00000000-0000-0000-0000-00000000C004',
 '[{"name": "gray", "colorCode": "0xFF808080"}, {"name": "White", "colorCode": "0xFFFFFFFF"}]',
 '[{"name": "Ryzen 7 / RTX 4060 / 16GB / 512GB", "price": 82445, "quantity": 4}, {"name": "Ryzen 7 / RTX 4060 / 16GB / 1TB", "price": 87945, "quantity": 2}, {"name": "Ryzen 9 / RTX 4070 / 32GB / 1TB", "price": 104445, "quantity": 1}]',
 true, false,
 '["AMD Ryzen 7/9 7000 Series processor", "NVIDIA GeForce RTX 4060/4070 graphics card", "16-inch WQXGA display with 165Hz refresh rate", "DDR5 RAM up to 32GB", "PCIe Gen4 SSD storage up to 1TB", "19.9mm thickness and only 2.4kg weight", "RGB backlit keyboard", "80Wh battery"]');

-------Clear all user-defined tables' contents
/*
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename NOT IN ('profiles', 'schema_migrations')
          AND tablename NOT LIKE 'pg_%'
          AND tablename NOT LIKE 'sql_%'
          AND tablename NOT LIKE 'auth%'
    )
    LOOP
        EXECUTE format('TRUNCATE TABLE public.%I CASCADE;', r.tablename);
    END LOOP;
END $$;
*/

---Clear specific table contents
--TRUNCATE TABLE "public"."tablename" CASCADE;

