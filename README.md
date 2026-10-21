# Design Tree

A map of Japanese designers, showing who they trained under, worked beside and influenced. It has EN/JP text, designer profiles with images, and accounts for profiles, pin boards and uploaded media.

The site is static: plain HTML, CSS and JavaScript, with no build step. It runs on GitHub Pages. Accounts, boards and uploads are stored in a free Supabase project.

```
index.html            the whole app (map, profiles, accounts, boards)
config.js             your Supabase URL + anon key (empty = preview mode)
vendor/supabase.js    Supabase browser client 2.45.4 (MIT, see supabase-LICENSE.txt)
images/               designer portraits and works (credits below)
supabase/schema.sql   database tables, security rules and storage bucket
```

## How accounts work

Accounts depend on what is in `config.js`.

| Mode | When | What happens |
|---|---|---|
| **Preview mode** | `config.js` values are empty (the default) | Everything works, but profiles, boards and uploads are saved only in the visitor's own browser. There's no password and no collaborators. |
| **Online mode** | `config.js` has your Supabase URL and anon key | Real accounts with e-mail and password. Boards, uploads and added designers are shared with everyone, and collaborators can be invited by e-mail. |

## 1. Put the site on GitHub Pages

1. On github.com, click **New repository**. Name it, for example, `design-tree`, and make it **Public**. Then **Create repository**.
2. Click **uploading an existing file**. Drag in **everything inside this folder**, including the `images`, `vendor` and `supabase` folders, then **Commit changes**.
   - `index.html` must be at the top level of the repository, not inside another folder.
3. Go to **Settings → Pages**.
   - Under **Build and deployment**, set Source to **Deploy from a branch**.
   - Set Branch to **main**, folder **/ (root)**, then **Save**.
4. After about a minute the site is live at `https://<your-username>.github.io/design-tree/`.

The site now runs in preview mode. Steps 2–4 turn on real accounts.

## 2. Create the Supabase project

1. Sign in at [supabase.com](https://supabase.com), then click **New project**.
   - Pick a name and a database password (keep the password somewhere safe).
   - Pick a region near you, for example Tokyo or US East.
2. When the project is ready, open **SQL Editor → New query**.
   - Paste the whole of `supabase/schema.sql` and click **Run**. It should finish with "Success. No rows returned".
   - The script is safe to run again later.
3. Open **Authentication → URL Configuration**.
   - **Site URL:** `https://<your-username>.github.io/design-tree/`
   - **Redirect URLs:** add the same address. This is what makes the confirmation and password-reset e-mails return to your site.
4. *(Optional)* E-mail confirmation is on by default: new accounts must click a link in an e-mail before they can log in.
   - For testing, you can turn it off in **Authentication → Sign In / Providers → Email → Confirm email**.
   - Supabase's built-in e-mail is limited to a few messages per hour. For a public launch, add your own SMTP under **Authentication → Emails → SMTP Settings**.

## 3. Connect the site to Supabase

1. In Supabase, open **Project Settings → API** and copy these two values:
   - **Project URL**, which looks like `https://abcdxyz.supabase.co`
   - **anon public** key, a long string starting with `eyJ…`
     - Newer projects call this the **publishable** key. That one works too.
2. In your GitHub repository, open `config.js`, click the pencil icon, paste both values, and **Commit changes**:

```js
window.DT_CONFIG = {
  supabaseUrl: "https://abcdxyz.supabase.co",
  supabaseAnonKey: "eyJhbGciOi..."
};
```

The anon key is designed to be public. The row level security rules in `schema.sql` decide who can read or change what.

**Never paste the `service_role` (secret) key into the site.**

## 4. Check it

Open your site in a private window, click the person icon and sign up. Then:

- Create a board from **+ → Create board**.
- Upload an image from **+ → Add media**.
- In Supabase, look at **Table Editor** (`profiles`, `boards`, `media`) and **Storage → media**. You should see the new rows and the uploaded file.

## What people can do

- **Profile** (person icon → Your profile):
  - Add a photo, a bio, favourite designers and favourite decades.
  - See their boards, a network map with their favourites highlighted, and their uploads.
- **Pin boards:**
  - Create a board from **+**, or with **Add to Board** on any designer's profile.
  - Add designers from the list on the right, add media, and set a cover.
  - Rename the board inline. Changes save automatically.
  - The owner can invite collaborators by e-mail. The invitee sees the invitation in their account menu after logging in with that address.
- **Add media:** upload an image for any designer, with the year and a description. Images are resized to at most 2000 px before upload. They appear under "From the community" on that designer's profile.
- **Add designer:** a new person joins the map, the chronological view, search and the lists. Anyone can open their profile.

## Rules the database enforces

- Anyone can view profiles, public boards, media and added designers.
- You can only edit your own profile, uploads and added designers.
- Board owners and collaborators can edit a board's content.
- Only the owner can delete a board, invite people, or change who owns or collaborates on it.
- Uploads go to `media/<your user id>/…`, and only you can write or delete there. Allowed types are JPEG, PNG, WebP and GIF, up to 10 MB.

## Image credits

- Designer images are from Wikimedia Commons, under the licences shown on each profile (Image credits, and in the enlarged view). Most are public domain or CC BY / CC BY-SA. CC BY-SA images stay under their licence when reused.
- Hara Hiromu's images come from the Design Tree research file.
