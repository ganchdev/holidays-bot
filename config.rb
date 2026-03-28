# frozen_string_literal: true

require 'json'

module Config
  RAILS_API_URL = ENV.fetch('RAILS_API_URL', 'http://localhost:3000')
  DEEPSEEK_API_KEY = ENV.fetch('DEEPSEEK_API_KEY', '')
  TELEGRAM_BOT_TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN', '')
end
