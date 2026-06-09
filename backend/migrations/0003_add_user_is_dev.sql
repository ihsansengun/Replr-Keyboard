-- Dev accounts: server-side test exemption. Requests from is_dev=1 users are
-- never charged credits (dev mode is test-only). Set manually — there is no API:
--   npx wrangler d1 execute replr-db --remote \
--     --command "UPDATE users SET is_dev=1 WHERE email='<dev email>'"
ALTER TABLE users ADD COLUMN is_dev INTEGER NOT NULL DEFAULT 0;
