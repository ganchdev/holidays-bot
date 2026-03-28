# frozen_string_literal: true

require 'json'
require 'http'

class DeepSeekClient
  API_URL = 'https://api.deepseek.com/chat/completions'

  TOOLS = [
    {
      type: 'function',
      function: {
        name: 'list_rooms',
        description: 'List all available rooms',
        parameters: { type: 'object', properties: {} }
      }
    },
    {
      type: 'function',
      function: {
        name: 'check_availability',
        description: 'Check if rooms are available for given dates',
        parameters: {
          type: 'object',
          properties: {
            starts: { type: 'string', description: 'Check-in date YYYY-MM-DD' },
            ends: { type: 'string', description: 'Check-out date YYYY-MM-DD' }
          },
          required: %w[starts ends]
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'list_bookings',
        description: 'List existing bookings',
        parameters: {
          type: 'object',
          properties: {
            starts: { type: 'string', description: 'Filter bookings from this date' },
            ends: { type: 'string', description: 'Filter bookings until this date' },
            room_id: { type: 'integer', description: 'Filter by room' },
            guest_id: { type: 'integer', description: 'Filter by guest' },
            status: { type: 'string', enum: %w[all active cancelled] }
          }
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'create_booking',
        description: 'Create a new booking',
        parameters: {
          type: 'object',
          properties: {
            room_id: { type: 'integer' },
            starts: { type: 'string', description: 'Check-in date YYYY-MM-DD' },
            ends: { type: 'string', description: 'Check-out date YYYY-MM-DD' },
            name: { type: 'string', description: 'Guest name' },
            adults: { type: 'integer', description: 'Number of adults' },
            children: { type: 'integer', description: 'Number of children' },
            notes: { type: 'string', description: 'Booking notes' },
            price: { type: 'number', description: 'Total price' },
            deposit: { type: 'number', description: 'Deposit amount' }
          },
          required: %w[room_id starts ends]
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'update_booking',
        description: 'Update an existing booking',
        parameters: {
          type: 'object',
          properties: {
            booking_id: { type: 'integer' },
            starts: { type: 'string' },
            ends: { type: 'string' },
            name: { type: 'string' },
            adults: { type: 'integer' },
            children: { type: 'integer' },
            notes: { type: 'string' },
            price: { type: 'number' },
            deposit: { type: 'number' }
          },
          required: ['booking_id']
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'search_guest',
        description: 'Search for a guest by name or email',
        parameters: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Guest name or email to search for' }
          },
          required: ['name']
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'get_guest_bookings',
        description: 'Get all bookings for a specific guest',
        parameters: {
          type: 'object',
          properties: {
            guest_id: { type: 'integer', description: 'Guest ID from search_guest' }
          },
          required: ['guest_id']
        }
      }
    }
  ].freeze

  def chat(messages, tool_result: false)
    body = {
      model: 'deepseek-chat',
      messages: messages,
      tools: TOOLS
    }
    body[:tool_choice] = 'auto' unless tool_result

    response = HTTP
               .headers(Authorization: "Bearer #{ENV.fetch('DEEPSEEK_API_KEY', nil)}")
               .post(API_URL, json: body)

    JSON.parse(response.body)
  end

  def system_prompt(language)
    case language
    when 'bg'
      <<~PROMPT
        Ти си хотелски бот. Отговаряй на български. Бъди кратък и любезен.
        Използвай само наличните инструменти. Не измисляй данни.
      PROMPT
    else
      <<~PROMPT
        You are a hotel booking assistant bot. Respond in the user's language.
        Be concise and friendly. Only use available tools. Do not make up data.
      PROMPT
    end
  end
end
