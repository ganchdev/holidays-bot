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
    @processed_ids = Set.new
    @conversations = {}  # chat_id => messages history

    @client = Telegram::Bot::Client.new(ENV.fetch('TELEGRAM_BOT_TOKEN', nil))
  end

  def run
    puts 'Bot starting...'
    client.run do |bot|
      bot.listen do |message|
        next unless message.is_a?(Telegram::Bot::Types::Message)
        next if already_processed?(message)

        @processed_ids.add(message.message_id)
        handle_message(bot, message)
      end
    end
  end

  private

  def already_processed?(message)
    if @processed_ids.include?(message.message_id)
      true
    else
      @processed_ids.clear if @processed_ids.size > 1000
      false
    end
  end

  def handle_message(bot, message)
    return unless message.text

    chat = message.chat
    text = message.text.to_s.strip
    session = db.get_session(chat.id)

    update_language(session, chat.id, message.from) if session

    case text
    when '/start'
      @conversations.delete(chat.id.to_s)
      bot.api.send_message(chat_id: chat.id, text: messages.welcome(message))
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
    bot.api.send_message(chat_id: chat.id, text: messages.login_link(email, chat.id))
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
    @conversations.delete(chat.id.to_s)
    bot.api.send_message(chat_id: chat.id, text: messages.logged_out)
  end

  MAX_CONVERSATION_MESSAGES = 20

  def handle_natural_language(bot, chat, text, session)
    messages.language = session['language'] || 'en'
    language = session['language'] || 'en'

    bot.api.send_message(chat_id: chat.id, text: messages.processing)

    # Get or initialize conversation history
    chat_id = chat.id.to_s
    @conversations[chat_id] ||= []

    # Add system prompt if history is empty
    if @conversations[chat_id].empty?
      @conversations[chat_id] << { role: 'system', content: deepseek.system_prompt(language, current_year: Time.now.year) }
    end

    # Add user message
    @conversations[chat_id] << { role: 'user', content: text }

    # Trim to max messages (keeping system prompt)
    trim_conversation(chat_id)

    puts "DEBUG: Sending to DeepSeek with #{@conversations[chat_id].length} messages..."
    result = deepseek.chat(@conversations[chat_id])
    puts "DEBUG: DeepSeek response: #{result.inspect[0..500]}"

    if result['error']
      puts "DEBUG: DeepSeek error: #{result['error']}"
      bot.api.send_message(chat_id: chat.id, text: "Грешка в AI: #{result['error']['message']}")
      return
    end

    message = result.dig('choices', 0, 'message')
    tool_calls = message&.dig('tool_calls')

    if tool_calls
      puts "DEBUG: Tool calls found: #{tool_calls.inspect}"
      @conversations[chat_id] << { role: 'assistant', content: message['content'], tool_calls: tool_calls }

      tool_calls.each do |tool_call|
        tool_name = tool_call.dig('function', 'name')
        arguments = JSON.parse(tool_call.dig('function', 'arguments') || '{}')
        puts "DEBUG: Executing tool: #{tool_name} with args: #{arguments.inspect}"

        tool_result = execute_tool(tool_name, arguments)
        puts "DEBUG: Tool result: #{tool_result.inspect}"

        @conversations[chat_id] << {
          role: 'tool',
          tool_call_id: tool_call['id'],
          content: tool_result.to_json
        }
      end

      final_result = deepseek.chat(@conversations[chat_id], tool_result: true)
      response = final_result.dig('choices', 0, 'message', 'content') || messages.error

      # Add final response to history
      @conversations[chat_id] << { role: 'assistant', content: response }
    else
      response = message&.dig('content') || messages.error
      @conversations[chat_id] << { role: 'assistant', content: response }
    end

    bot.api.send_message(chat_id: chat.id, text: response)
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
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

  def update_language(session, chat_id, from)
    return unless session

    new_lang = from.language_code&.start_with?('bg') ? 'bg' : 'en'
    return if session['language'] == new_lang

    db.update_language(chat_id, new_lang)
  end

  def trim_conversation(chat_id)
    return if @conversations[chat_id].length <= MAX_CONVERSATION_MESSAGES

    # Keep system prompt (first message) and trim older messages
    system_prompt = @conversations[chat_id].first
    rest = @conversations[chat_id][1..]

    # Keep last MAX_CONVERSATION_MESSAGES - 1 messages (plus system = MAX)
    @conversations[chat_id] = [system_prompt] + rest.last(MAX_CONVERSATION_MESSAGES - 1)
  end

  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
  end
end

Bot.new.run if __FILE__ == $PROGRAM_NAME
