CREATE TABLE IF NOT EXISTS public.support_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

-- Allow users to insert their own support requests
CREATE POLICY "Users can insert own support requests"
ON public.support_requests
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to view their own support requests
CREATE POLICY "Users can view own support requests"
ON public.support_requests
FOR SELECT
USING (auth.uid() = user_id);
