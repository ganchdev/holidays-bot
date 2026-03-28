# Telegram Bot + DeepSeek Agent - Architecture Plan

## Status: Phase 1 Complete → Phase 2 (Telegram Bot) Pending

### Phase 1 Complete ✅

All Rails API endpoints are ready:
- `POST /api/v1/auth/verify` - Verify Telegram login code
- `GET /api/v1/rooms` - List all rooms
- `GET /api/v1/availability` - Check room availability
- `GET /api/v1/guests` - Search guests by name
- `GET/POST/PATCH /api/v1/bookings` - CRUD bookings
- `GET /bot_verify` - Web page for verification codes

---

## Overview
Build a Telegram bot with DeepSeek-powered agent that allows AuthorizedUsers to:
- Check room availability via natural language
- CRUD bookings (except Delete) via natural language
- Search guests and view booking history
- Get responses in their preferred language

---

## Telegram Bot API Features

| Feature | Use Case |
|---------|----------|
| **Long Polling** | Receive messages from users (no webhook/HTTPS needed) |
| **Send Message** | Respond to user queries |
| **Commands** | `/start`, `/login`, `/help` |
| **Reply Markups** | Login flow (enter email, enter code) |
| **Markdown/HTML** | Format responses nicely |

**Not used:**
- Inline queries, Callbacks, Media, Webhooks, Groups

**Languages:** Bulgarian (BG) + English (EN)

---

## Tech Stack
- **Rails App**: Ruby on Rails 8 (existing) - runs in Docker container
- **Telegram Bot**: Ruby (telegram-bot-ruby gem) - runs in separate Docker container
- **LLM**: DeepSeek API (cheap for basic tasks)
- **Database**: SQLite3 (existing Rails DB)
- **Bot State**: SQLite3 (simple auth mapping)
- **Deployment**: Same VM (OS & resources), separate Docker containers

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VM (Host)                           │
│                                                             │
│   ┌─────────────────────────┐   ┌────────────────────────┐ │
│   │    Rails App Container   │   │   Telegram Bot Container│ │
│   │                         │   │                        │ │
│   │  API Mode               │◀──│── HTTP/REST            │ │
│   │  POST /api/v1/auth/verify│   │                        │ │
│   │  GET  /api/v1/rooms     │   │  Ruby Bot              │ │
│   │  GET  /api/v1/availability│  │  • DeepSeek client     │ │
│   │  GET  /api/v1/bookings  │   │  • Tool handlers       │ │
│   │  POST /api/v1/bookings  │   │  • SQLite (auth state) │ │
│   │  PATCH /api/v1/bookings/:id│ └────────────────────────┘ │
│   └─────────────────────────┘                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## How It Works

### Tool Execution Flow

```
User: "Do we have a room June 15-17?"
         │
         ▼
    DeepSeek (decides: "call check_availability")
         │
         ▼
     Bot's Ruby function executes check_availability()
         │
         ├── Calls Rails API: GET /api/v1/availability?starts=XX&ends=XX
         │
         ▼
    Bot sends result back to DeepSeek
         │
         ▼
    DeepSeek formats natural language response (in user's language)
         │
         ▼
    Bot sends response to user
```

### DeepSeek Function Calling (Tools)

Tools are defined in the API call. DeepSeek returns structured JSON, not freeform text:

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "list_rooms",
        "description": "List all available rooms",
        "parameters": {
          "type": "object",
          "properties": {}
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "check_availability",
        "description": "Check if rooms are available for given dates",
        "parameters": {
          "type": "object",
          "properties": {
            "starts": {"type": "string", "description": "Check-in date YYYY-MM-DD"},
            "ends": {"type": "string", "description": "Check-out date YYYY-MM-DD"}
          },
          "required": ["starts", "ends"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "list_bookings",
        "description": "List existing bookings",
        "parameters": {
          "type": "object",
          "properties": {
            "starts": {"type": "string", "description": "Filter bookings from this date"},
            "ends": {"type": "string", "description": "Filter bookings until this date"},
            "room_id": {"type": "integer", "description": "Filter by room"},
            "guest_id": {"type": "integer", "description": "Filter by guest"},
            "status": {"type": "string", "enum": ["all", "active", "cancelled"]}
          }
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "create_booking",
        "description": "Create a new booking",
        "parameters": {
          "type": "object",
          "properties": {
            "room_id": {"type": "integer"},
            "starts": {"type": "string", "description": "Check-in date YYYY-MM-DD"},
            "ends": {"type": "string", "description": "Check-out date YYYY-MM-DD"},
            "adults": {"type": "integer", "description": "Number of adults"},
            "children": {"type": "integer", "description": "Number of children"},
            "notes": {"type": "string", "description": "Booking notes"}
          },
          "required": ["room_id", "starts", "ends"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "update_booking",
        "description": "Update an existing booking",
        "parameters": {
          "type": "object",
          "properties": {
            "booking_id": {"type": "integer"},
            "starts": {"type": "string"},
            "ends": {"type": "string"},
            "adults": {"type": "integer"},
            "children": {"type": "integer"},
            "notes": {"type": "string"}
          },
          "required": ["booking_id"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "search_guest",
        "description": "Search for a guest by name or email",
        "parameters": {
          "type": "object",
          "properties": {
            "name": {"type": "string", "description": "Guest name or email to search for"}
          },
          "required": ["name"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_guest_bookings",
        "description": "Get all bookings for a specific guest",
        "parameters": {
          "type": "object",
          "properties": {
            "guest_id": {"type": "integer", "description": "Guest ID from search_guest"}
          },
          "required": ["guest_id"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_guest_total_spent",
        "description": "Calculate total amount paid by a guest",
        "parameters": {
          "type": "object",
          "properties": {
            "guest_id": {"type": "integer", "description": "Guest ID from search_guest"}
          },
          "required": ["guest_id"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_occupancy",
        "description": "Get room occupancy statistics for a date range",
        "parameters": {
          "type": "object",
          "properties": {
            "starts": {"type": "string", "description": "Start date YYYY-MM-DD"},
            "ends": {"type": "string", "description": "End date YYYY-MM-DD"}
          },
          "required": ["starts", "ends"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_revenue",
        "description": "Get revenue statistics for a date range",
        "parameters": {
          "type": "object",
          "properties": {
            "starts": {"type": "string", "description": "Start date YYYY-MM-DD"},
            "ends": {"type": "string", "description": "End date YYYY-MM-DD"}
          },
          "required": ["starts", "ends"]
        }
      }
    }
  ]
}
```

Example DeepSeek response:
```json
{
  "name": "check_availability",
  "arguments": {
    "starts": "2025-06-15",
    "ends": "2025-06-17"
  }
}
```

---

## Multi-Step Queries

DeepSeek can chain multiple tools to answer complex questions:

```
User: "Has John Doe ever stayed with us?"

DeepSeek calls: search_guest("John Doe")
  → Bot calls: GET /api/v1/guests?search=John%20Doe
  → Returns: [{"name": "John Doe", "id": 5}]

DeepSeek calls: get_guest_bookings(guest_id=5)  
  → Bot calls: GET /api/v1/bookings?guest_id=5
  → Returns: [Booking 2023-08-01, Booking 2024-06-15]

DeepSeek responds: "Yes, John Doe has stayed with us twice before..."
```

**Text-only requests (no tool needed):**
DeepSeek can also format/transform data without new tools:
- "Format it like an invoice"
- "Summarize this list"
- "Draft a message to the guest"

---

## Authentication Flow

### Step-by-Step

```
1. User in Telegram: /login
2. Bot: "Please enter your email address"
3. User types: "john@example.com"
4. Bot: "Open this link in your browser: https://yourapp.com/bot_verify?chat_id=123&email=john@example.com"
5. User opens link in browser → sees verification CODE on screen
6. User types CODE "123456" back in Telegram
7. Bot calls: POST /api/v1/auth/verify with code + chat_id
8. Bot receives user info → logged in
```

### Components

| Component | Purpose |
|-----------|---------|
| `BotVerifyController` (Web) | Creates BotVerification record, displays code in browser |
| `BotController#verify` (API) | Validates code, returns user info, deletes code |

### After Login

- Telegram always provides `chat_id` with each message
- Bot stores mapping in SQLite: `chat_id → user_id`
- Session persists indefinitely until manually revoked

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
    │◀──"Check web for code"───│                            │
    │                           │                            │
    │──── 123456 ───────────────│                            │
    │     (enter code)          │                            │
    │                           │                            │
    │──── verify API ───────────│───────────────────────────▶│
    │                           │                          Validates code
    │◀──"You're logged in!"────│◀──user info──────────────│
```

---

## Complete Function List

### Availability & Rooms
| Tool | Purpose |
|------|---------|
| `list_rooms` | Get all rooms |
| `check_availability` | Find available rooms for dates |

### Bookings (CRU)
| Tool | Purpose |
|------|---------|
| `list_bookings` | List bookings (filterable by date, status, room, guest) |
| `create_booking` | Create new booking |
| `update_booking` | Update existing booking (dates, guests, notes) |

### Guests
| Tool | Purpose |
|------|---------|
| `search_guest` | Find guest by name or email |
| `get_guest_bookings` | Get all bookings for a guest |

### Reporting (v2)
| Tool | Purpose |
|------|---------|
| `get_guest_total_spent` | Calculate total amount paid by guest |
| `get_occupancy` | Room occupancy stats for date range |
| `get_revenue` | Revenue stats for date range |

---

## Rails API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/verify` | Verify Telegram code, return user info |

### Rooms
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/rooms` | List all rooms |

### Availability
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/availability?starts=YYYY-MM-DD&ends=YYYY-MM-DD` | List available rooms for dates |

### Guests
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/guests?search=Name` | Search guests by name or email |

### Bookings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/bookings` | List bookings (supports `guest_id`, `status`, `starts`, `ends` filters) |
| POST | `/api/v1/bookings` | Create booking |
| PATCH | `/api/v1/bookings/:id` | Update booking |

### Reporting (v2)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/guests/:id/total_spent` | Total amount paid by guest |
| GET | `/api/v1/reports/occupancy?starts=&ends=` | Occupancy stats for date range |
| GET | `/api/v1/reports/revenue?starts=&ends=` | Revenue stats for date range |

---

## Bot State (SQLite)

```sql
CREATE TABLE sessions (
  chat_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pending_verifications (
  chat_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL
);
```

---

## Directory Structure

```
holidays-bot/                    # Bot repository (this repo)
├── docs/
│   └── telegram-bot-plan.md
├── Gemfile
├── bot.rb                      # Main entry point
├── config.rb                   # Configuration
├── Dockerfile                  # Ruby slim container
├── docker-compose.yml          # Bot + Rails containers
├── .env.example
├── db/
│   └── schema.sql              # SQLite schema
└── lib/
    ├── database.rb             # SQLite session management
    ├── api_client.rb           # Rails API HTTP client
    ├── deepseek_client.rb      # DeepSeek with tool definitions
    ├── messages.rb             # BG/EN localization
    └── tools/
        ├── rooms.rb
        ├── bookings.rb
        └── guests.rb
```

## Rails App Connection

The bot connects to the Rails API (running in `holidays/` directory):
- API URL: Configurable via `RAILS_API_URL` env var
- Auth: POST `/api/v1/auth/verify`
- Rooms: GET `/api/v1/rooms`
- Availability: GET `/api/v1/availability?starts=&ends=`
- Guests: GET `/api/v1/guests?search=`
- Bookings: GET/POST/PATCH `/api/v1/bookings`

---

## Implementation Order

### Phase 1: Rails API ✅ Complete

| Task | Status | Files |
|------|--------|-------|
| API routes setup | ✅ Done | `config/routes.rb` |
| BotApiController (rooms, availability, guests, bookings) | ✅ Done | `app/controllers/api/v1/bot_controller.rb` |
| BotVerification model | ✅ Done | `app/models/bot_verification.rb` |
| BotVerification migration | ✅ Done | `db/migrate/20250327000000_create_bot_verifications.rb` |
| Run migration | ✅ Done | (ran in dev) |
| Web endpoint for verification code generation | ✅ Done | `app/controllers/bot_verify_controller.rb`, `app/views/bot_verify/show.html.erb`, `config/routes.rb` |
| Add `guest_id` filter to bookings endpoint | ✅ Done | `app/controllers/api/v1/bot_controller.rb` |

### Phase 2: Telegram Bot ✅ In Progress

| Task | Status | Notes |
|------|--------|-------|
| Project scaffolding | ✅ Done | `Gemfile`, `bot.rb`, `config.rb` |
| Bot SQLite schema (sessions, pending_verifications) | ✅ Done | `db/schema.sql` |
| Long polling message handler | ✅ Done | `bot.rb` |
| /start, /help commands | ✅ Done | `bot.rb` |
| /login command + email flow | ✅ Done | `bot.rb`, `lib/messages.rb` |
| DeepSeek client + tool definitions | ✅ Done | `lib/deepseek_client.rb` |
| Tool handlers (all v1 tools) | ✅ Done | `lib/api_client.rb`, `lib/tools/*.rb` |
| BG/EN localization | ✅ Done | `lib/messages.rb` |
| Docker setup | ✅ Done | `Dockerfile`, `docker-compose.yml` |

### Phase 3: Testing ✅ Pending

| Task | Status | Notes |
|------|--------|-------|
| API endpoint testing | ⬜ Pending | curl or Postman |
| Bot end-to-end testing | ⬜ Pending | Real Telegram messages |
| Sample queries | ⬜ Pending | Availability, bookings, guest search |

### Phase 4: Reporting (Optional) ✅ Pending

| Task | Status | Notes |
|------|--------|-------|
| get_guest_total_spent | ⬜ Pending | Rails endpoint + Ruby tool |
| get_occupancy | ⬜ Pending | Rails endpoint + Ruby tool |
| get_revenue | ⬜ Pending | Rails endpoint + Ruby tool |

---

## Files Created

### Rails App
- `config/routes.rb` - Updated with `/api/v1/*` routes
- `app/controllers/api/v1/bot_api_controller.rb` - API endpoints
- `app/models/bot_verification.rb` - Verification code model
- `db/migrate/20250327000000_create_bot_verifications.rb` - Migration

### Bot (created)
- `Gemfile` - Ruby dependencies (telegram-bot-ruby, sqlite3, dotenv)
- `bot.rb` - Main entry point
- `config.rb` - Configuration
- `db/schema.sql` - SQLite schema for sessions
- `lib/database.rb` - Session management
- `lib/api_client.rb` - Rails API HTTP client
- `lib/deepseek_client.rb` - DeepSeek API with tool definitions
- `lib/messages.rb` - BG/EN localization
- `Dockerfile` - Ruby slim container
- `docker-compose.yml` - Bot + Rails containers
- `.env.example` - Environment variables
