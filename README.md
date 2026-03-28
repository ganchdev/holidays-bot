# Holidays Telegram Bot

A Telegram bot with DeepSeek-powered natural language interface for hotel booking management.

## Features

- Natural language queries for room availability
- CRUD operations for bookings (except delete)
- Guest search and booking history
- Bulgarian and English localization
- Secure login via verification code

## Setup

```bash
cp .env.example .env
# Edit .env with your tokens
bundle install
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token from @BotFather |
| `DEEPSEEK_API_KEY` | DeepSeek API key |
| `RAILS_API_URL` | Rails API URL (default: http://localhost:3000) |

## Running

```bash
bundle exec ruby bot.rb
```

## Docker

```bash
docker-compose up --build
```

## Commands

| Command | Description |
|---------|-------------|
| `/start` | Start the bot |
| `/login` | Log in with email |
| `/logout` | Log out |
| `/help` | Show help |

## Login Flow

1. `/login` → enter email address
2. Bot shows link to verification page
3. Open link in browser → note the 6-digit code
4. Enter code in Telegram → logged in

## Tech Stack

- Ruby 3.3
- telegram-bot-ruby
- DeepSeek API (function calling)
- SQLite (session storage)
