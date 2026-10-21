/* Design Tree — connection settings.
   Leave both values empty to run in preview mode (profiles, boards and media are kept in the visitor's browser).
   To turn on real accounts, paste your Supabase project's URL and anon (public) key from
   Supabase → Project Settings → API. The anon key is meant to be public; row level security in
   supabase/schema.sql is what protects the data. Never put the service_role key here. */
window.DT_CONFIG = {
  supabaseUrl: "",
  supabaseAnonKey: ""
};
