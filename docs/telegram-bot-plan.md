# Telegram Bot - Architecture Plan

## Status: Complete ✅

The Telegram bot with DeepSeek-powered natural language interface is fully implemented.

---

## Overview

A Telegram bot with DeepSeek-powered agent that allows AuthorizedUsers to:
- Check room availability via natural language
- CRUD bookings via natural language
- Search guests and view booking history
- Get responses in Bulgarian or English
- Secure login via web verification

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Telegram Bot | Ruby (telegram-bot-ruby gem) |
| LLM | DeepSeek API (function calling) |
| Bot State | SQLite3 |
| Rails API | Ruby on Rails 8 |
| Deployment | Docker containers |

---

## Authentication Flow

### Step-by-Step

```
1. User in Telegram: /login
2. Bot: "Please enter your email address"
3. User types: "john@example.com"
4. Bot: "Open this link: https://app.com/bot_verify?chat_id=123&email=john@example.com"
5. User opens link in browser:
   - IF logged into web app AND email matches → sees verification CODE
   - IF not logged in → redirect to /auth (Google login)
   - IF email mismatch → show error
6. User types CODE "123456" back in Telegram
7. Bot calls: POST /api/v1/auth/verify with code + chat_id
8. API returns: { success: true, user: {...}, token: "..." }
9. Bot stores token in SQLite, uses for all future API calls
```

### Token-Based API Authentication

All API endpoints (except `/verify`) require authentication:

```
Authorization: Bearer <token>
```

The token is stored in the bot's SQLite database and linked to the user's account.

### Visual Reference

```
Telegram                    Web Browser                    Rails API
    │                           │                            │
    │──── /login ───────────────│                            │
    │     (enter email)         │                            │
    │                           │                            │
    │                           │──GET /bot_verify?───▶     │
    │                           │                          Creates BotVerification
    │                           │◀──shows code───────────   │
    │◀──"Open link"───────────│                            │
    │                           │                            │
    │──── 123456 ───────────────│                            │
    │     (enter code)          │                            │
    │──── verify API ───────────│───────────────────────────▶│
    │                           │                          Validates code
    │◀──"Welcome!"─────────────│◀──user info + token──────│
```

---

## Bot State (SQLite)

```sql
CREATE TABLE sessions (
  chat_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  user_name TEXT,
  user_email TEXT,
  token TEXT,
  language TEXT DEFAULT 'bg',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pending_verifications (
  chat_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## DeepSeek Features

### Function Calling

The bot uses DeepSeek's function calling to execute API operations:

| Tool | Purpose |
|------|---------|
| `list_rooms` | Get all rooms |
| `check_availability` | Find available rooms for dates |
| `list_bookings` | List bookings (filterable) |
| `create_booking` | Create new booking |
| `update_booking` | Update existing booking |
| `search_guest` | Find guest by name/email |
| `get_guest_bookings` | Get bookings for a guest |

### System Prompt

The bot's behavior is controlled by a system prompt that:
- Enforces Bulgarian language (responses only in Bulgarian, not Russian)
- Always uses current year unless specified
- Always uses Euro (€) for currency
- Parses Bulgarian date formats (юли = July, август = August, etc.)
- Uses HTML formatting in responses (`<b>`, `<i>`, `<code>`)
- Calls tools immediately without asking for confirmation

### Conversation Memory

The bot maintains conversation history (20 messages max per chat):
- Remembers dates and context from previous messages
- User can say "that room" or "the same dates" in follow-up messages
- History clears on `/start` or `/logout`

### Date Parsing

The bot understands Bulgarian date formats:
- "2 до 6 юли" → 2026-07-02 to 2026-07-06
- "03-07 юли" → 2026-07-03 to 2026-07-07
- "15 август" → 2026-08-15
- "лятото" → June-August (season)

---

## Rails API Endpoints

All endpoints (except verify) require `Authorization: Bearer <token>` header.

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/verify` | Verify code, returns user info + token |

### Rooms
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/rooms` | List all rooms |

### Availability
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/availability?starts=&ends=` | List available rooms |

### Guests
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/guests?search=` | Search guests |

### Bookings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/bookings` | List bookings |
| POST | `/api/v1/bookings` | Create booking |
| PATCH | `/api/v1/bookings/:id` | Update booking |

---

## Directory Structure

```
holidays-bot/                    # Bot repository
├── .env.example                # Environment variables template
├── .gitignore
├── .rubocop.yml
├── .ruby-version
├── Dockerfile
├── docker-compose.yml
├── Gemfile
├── README.md
├── bot.rb                      # Main entry point
├── config.rb                   # Configuration
├── db/
│   └── schema.sql             # SQLite schema
└── lib/
    ├── api_client.rb           # Rails API HTTP client (with token auth)
    ├── database.rb             # SQLite session management
    ├── deepseek_client.rb      # DeepSeek with tool definitions
    └── messages.rb             # BG/EN localization
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token from @BotFather |
| `DEEPSEEK_API_KEY` | DeepSeek API key |
| `RAILS_API_URL` | Rails API URL (default: http://localhost:3000) |

---

## Commands

| Command | Description |
|---------|-------------|
| `/start` | Start bot, clear conversation |
| `/login` | Start login flow |
| `/logout` | Log out, clear conversation |
| `/help` | Show help message |

---

## HTML Formatting

All bot messages use HTML parse mode. The DeepSeek prompt instructs the AI to use:
- `<b>text</b>` for bold
- `<i>text</i>` for italic
- `<code>text</code>` for code/numbers
