-- ControlDeck native Notes admin write permissions
-- Run this in the SQL Editor of the Supabase project used by the Notes app.
-- Admin identity is checked by the database JWT email claim, not only by Flutter UI.
-- The Notes custom-auth JWT must include an "email" claim for these policies to work.

grant select, insert, update, delete on notes.languages, notes.topics, notes.topic_content to authenticated;

drop policy if exists "Notes admin manages languages" on notes.languages;
create policy "Notes admin manages languages" on notes.languages
  for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com');

drop policy if exists "Notes admin manages topics" on notes.topics;
create policy "Notes admin manages topics" on notes.topics
  for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com');

drop policy if exists "Notes admin manages lesson content" on notes.topic_content;
create policy "Notes admin manages lesson content" on notes.topic_content
  for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'amanjain033@gmail.com');
