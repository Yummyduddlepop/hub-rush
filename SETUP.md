# Publishing Hub Rush

The game runs on GitHub Pages (free hosting) and the leaderboard lives in Supabase (free database).
Players open one link, type a name, and play. No login.

## 1. Create the leaderboard database (Supabase)

1. Go to https://supabase.com and sign up (free plan).
2. Click **New project**. Name it `hub-rush`, choose the region closest to your players
   (Southeast Asia (Singapore) for the Philippines), and set a database password. Keep that password to yourself.
3. When the project is ready, open **SQL Editor** → **New query**.
4. Open `supabase-setup.sql` from this folder, copy everything, paste it in, and click **Run**.
   You should see "Success. No rows returned".
5. Open **Project Settings** → **API Keys** (or **Data API**) and copy:
   - the **Project URL** (looks like `https://abcdxyz.supabase.co`)
   - the **publishable key** (starts with `sb_publishable_`), or the legacy **anon public** key (starts with `eyJ`)

   Never share the **secret** or **service_role** key. The game doesn't need it.

## 2. Put the game online (GitHub Pages)

1. Go to https://github.com and sign up (free).
2. Sign in from this PC by running `gh auth login` in a terminal, then choose
   GitHub.com → HTTPS → Login with a web browser.

Claude then creates the `hub-rush` repository, uploads `index.html`, and turns on Pages.
The game link will be `https://YOUR-GITHUB-NAME.github.io/hub-rush/`. Turn that link into a QR code.

## Looking after it

- **Remove a name:** Supabase → **Table Editor** → `hub_scores` → select the row → **Delete**.
- **Reset the leaderboard:** run `delete from hub_scores;` in the SQL Editor.
- **Inactivity pause:** Supabase pauses free projects after about a week with no activity.
  If the leaderboard stops loading after a quiet period, open the project in Supabase and click **Restore**.
  The game itself keeps working while the leaderboard is paused.
