-- Sessions table: chat_id -> user_id mapping with token
CREATE TABLE IF NOT EXISTS sessions (
  chat_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  user_name TEXT,
  user_email TEXT,
  token TEXT,
  language TEXT DEFAULT 'en',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Pending verifications: code -> chat_id for login flow
CREATE TABLE IF NOT EXISTS pending_verifications (
  chat_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
