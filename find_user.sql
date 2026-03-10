-- Find user by email
SELECT id, email FROM auth.users WHERE email = 'xyzminhaj@gmail.com';
SELECT id, tier, is_premium FROM public.profiles WHERE id IN (SELECT id FROM auth.users WHERE email = 'xyzminhaj@gmail.com');
