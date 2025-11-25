-- Fix RLS Policies for Bottle Sending
-- This ensures the app can insert and update bottles properly

-- ========================================
-- 1. FIX SENT_BOTTLES RLS POLICIES
-- ========================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own sent bottles" ON sent_bottles;
DROP POLICY IF EXISTS "Users can insert their own sent bottles" ON sent_bottles;
DROP POLICY IF EXISTS "Users can update their own sent bottles" ON sent_bottles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON sent_bottles;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON sent_bottles;

-- Create new policies
CREATE POLICY "Users can view their own sent bottles"
  ON sent_bottles FOR SELECT
  USING (auth.uid() = sender_id);

CREATE POLICY "Users can insert their own sent bottles"
  ON sent_bottles FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own sent bottles"
  ON sent_bottles FOR UPDATE
  USING (auth.uid() = sender_id);

-- ========================================
-- ========================================
-- 2. FIX RECEIVED_BOTTLES RLS POLICIES
-- ========================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Users can insert received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Users can update their own received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON received_bottles;

-- Create new policies
CREATE POLICY "Users can view their own received bottles"
  ON received_bottles FOR SELECT
  USING (auth.uid() = receiver_id);

CREATE POLICY "Users can insert received bottles"
  ON received_bottles FOR INSERT
  WITH CHECK (true); -- Allow any authenticated user to insert (for matching system)

CREATE POLICY "Users can update their own received bottles"
  ON received_bottles FOR UPDATE
  USING (auth.uid() = receiver_id);

-- ========================================
-- 3. FIX BOTTLE_DELIVERY_QUEUE RLS POLICIES
-- ========================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own queued bottles" ON bottle_delivery_queue;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON bottle_delivery_queue;
DROP POLICY IF EXISTS "Enable update for system" ON bottle_delivery_queue;

-- Create new policies
CREATE POLICY "Users can view their own queued bottles"
  ON bottle_delivery_queue FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Enable insert for authenticated users"
  ON bottle_delivery_queue FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Enable update for system"
  ON bottle_delivery_queue FOR UPDATE
  USING (true); -- Allow updates for delivery system

-- ========================================
-- 4. VERIFY POLICIES
-- ========================================

SELECT 
  tablename,
  policyname,
  cmd as operation,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END as using_status,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END as check_status
FROM pg_policies
WHERE tablename IN ('sent_bottles', 'received_bottles', 'bottle_delivery_queue')
ORDER BY tablename, policyname;
