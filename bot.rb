# frozen_string_literal: true

require 'telegram/bot'
require_relative 'lib/database'
require_relative 'lib/api_client'
require_relative 'lib/deepseek_client'
require_relative 'lib/messages'
require 'dotenv/load'

class Bot

  attr_reader :client, :db, :api_client, :deepseek, :messages

  def initialize
    @db = Database.new
    @api_client = ApiClient.new
    @deepseek = DeepSeekClient.new
    @messages = Messages.new

    @client = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
  end

  def run
    puts 'Bot starting...'
    client.run do |bot|
      bot.on(:update) { |update| handle_update(bot, update) }
    end
  end

  private

  def handle_update(bot, update)
    return unless update.message

    chat = update.message.chat
    text = update.message.text.to_s.strip
    session = db.get_session(chat.id)

    update_language(session, bot, chat) if session

    case text
    when '/start'
      bot.api.send_message(chat_id: chat.id, text: messages.welcome(update.message))
    when '/help'
      bot.api.send_message(chat_id: chat.id, text: messages.help)
    when '/login'
      handle_login_start(bot, chat)
    when '/logout'
      handle_logout(bot, chat)
    else
      if text.match?(/^\d{6}$/)
        handle_verification_code(bot, chat, text)
      elsif text.include?('@')
        handle_email_input(bot, chat, text)
      elsif session
        handle_natural_language(bot, chat, text, session)
      else
        bot.api.send_message(chat_id: chat.id, text: messages.not_authenticated)
      end
    end
  end

  def handle_login_start(bot, chat)
    pending = db.get_pending_verification(chat.id)
    db.delete_pending_verification(chat.id) if pending
    bot.api.send_message(chat_id: chat.id, text: messages.login_prompt)
  end

  def handle_email_input(bot, chat, email)
    return bot.api.send_message(chat_id: chat.id, text: messages.invalid_email) unless valid_email?(email)

    db.set_pending_verification(chat.id, email)
    bot.api.send_message(chat_id: chat.id, text: format(messages.login_link(email), chat_id: chat.id))
  end

  def handle_verification_code(bot, chat, code)
    pending = db.get_pending_verification(chat.id)
    unless pending
      bot.api.send_message(chat_id: chat.id, text: messages.not_authenticated)
      return
    end

    result = api_client.verify(chat.id, code)

    if result['success']
      user = result['user']
      db.save_session(chat.id, user['id'], user['name'], user['email'])
      db.delete_pending_verification(chat.id)
      bot.api.send_message(chat_id: chat.id, text: messages.login_success(user['name']))
    else
      bot.api.send_message(chat_id: chat.id, text: messages.invalid_code)
    end
  end

  def handle_logout(bot, chat)
    db.delete_session(chat.id)
    bot.api.send_message(chat_id: chat.id, text: messages.logged_out)
  end

  def handle_natural_language(bot, chat, text, session)
    messages.language = session['language'] || 'en'

    bot.api.send_message(chat_id: chat.id, text: messages.processing)

    system_msg = { role: 'system', content: deepseek.system_prompt(session['language'] || 'en') }
    messages_history = [system_msg, { role: 'user', content: text }]

    result = deepseek.chat(messages_history)

    if result['tool_calls']
      messages_history << { role: 'assistant', content: nil, tool_calls: result['tool_calls'] }

      result['tool_calls'].each do |tool_call|
        tool_name = tool_call.dig('function', 'name')
        arguments = JSON.parse(tool_call.dig('function', 'arguments') || '{}')

        tool_result = execute_tool(tool_name, arguments)
        messages_history << {
          role: 'tool',
          tool_call_id: tool_call['id'],
          content: tool_result.to_json
        }
      end

      final_result = deepseek.chat(messages_history, tool_result: true)
      response = final_result.dig('choices', 0, 'message', 'content') || messages.error
    else
      response = result.dig('choices', 0, 'message', 'content') || messages.error
    end

    bot.api.send_message(chat_id: chat.id, text: response)
  rescue StandardError => e
    puts "Error: #{e.message}"
    bot.api.send_message(chat_id: chat.id, text: messages.error)
  end

  def execute_tool(name, args)
    case name
    when 'list_rooms'
      api_client.rooms
    when 'check_availability'
      api_client.availability(starts: args['starts'], ends: args['ends'])
    when 'list_bookings'
      api_client.bookings(args)
    when 'create_booking'
      api_client.create_booking(args)
    when 'update_booking'
      api_client.update_booking(args['booking_id'], args)
    when 'search_guest'
      api_client.guests(search: args['name'])
    when 'get_guest_bookings'
      api_client.bookings(guest_id: args['guest_id'])
    else
      { error: "Unknown tool: #{name}" }
    end
  end

  def update_language(session, _bot, chat)
    return unless session

    new_lang = chat.language_code&.start_with?('bg') ? 'bg' : 'en'
    return if session['language'] == new_lang

    db.update_language(chat.id, new_lang)
  end

  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
  end
end

Bot.new.run if __FILE__ == $PROGRAM_NAME
