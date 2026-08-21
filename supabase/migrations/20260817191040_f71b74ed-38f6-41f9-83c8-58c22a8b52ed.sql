UPDATE auth.users
SET encrypted_password = extensions.crypt('REDACTED_ROTATED_OUT_OF_BAND', extensions.gen_salt('bf')),
    email_confirmed_at = COALESCE(email_confirmed_at, now()),
    confirmation_token = '',
    recovery_token = '',
    recovery_sent_at = NULL,
    updated_at = now()
WHERE lower(email) = 'admin@agricapital.ci';