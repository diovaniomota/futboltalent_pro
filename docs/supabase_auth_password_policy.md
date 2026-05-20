# Supabase Auth password policy

The Flutter app validates password strength before calling `signUp`, but Supabase
Auth must also reject weak passwords so the rule cannot be bypassed by a direct
API call.

This repository does not contain a `supabase/config.toml`, a Supabase CLI setup,
or an Auth configuration migration that can enforce hosted Auth password policy
from code. Configure the hosted project directly in the Supabase Dashboard:

1. Open Supabase Dashboard.
2. Select the FutbolTalent project.
3. Go to Authentication > Providers > Email.
4. Open Password security / Password strength settings.
5. Set Minimum password length to 8 or higher.
6. Require all character groups:
   - lowercase letter;
   - uppercase letter;
   - number;
   - special character / symbol.
7. If the project plan supports it, enable leaked password protection.
8. Save the provider settings.
9. Test `auth.signUp` directly with a weak password and confirm Supabase returns
   a weak-password error before user creation.

Keep this Dashboard policy in sync with the app-side validator used by Player
and Club onboarding. BUG-ONB-010 should not be considered fully closed in any
environment where this Dashboard policy has not been applied.
