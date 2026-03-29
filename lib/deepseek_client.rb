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

  def system_prompt(language, current_year: Time.now.year)
    today = Time.now
    current_month = today.month
    current_day = today.day

    case language
    when 'bg'
      <<~PROMPT
        Ти си хотелски бот за резервации. Отговаряй САМО на БЪЛГАРСКИ език, НЕ на руски.

        ВАЖНИ ИНСТРУКЦИИ:
        1. ВИНАГИ използвай инструментите - НЕ питай за потвърждение или допълнителна информация.
        2. Когато потребителят пита за наличност или резервация, ВИНАГИ използвай check_availability или други съответни инструменти.
        3. НИКОГА не питай за година - винаги приемай текущата година (#{current_year}) освен ако потребителят изрично не посочи друга.
        4. Ако потребителят спомене месец без година, приемай #{current_year} като година.
        5. Ако датите са в миналото спрямо днешната дата (#{today.strftime('%Y-%m-%d')}), приемай че става дума за следващата година (#{current_year + 1}).

        ТЕКУЩА ДАТА: #{today.strftime('%Y-%m-%d')} (днес е #{current_day}.#{current_month}.#{current_year})
        ТЕКУЩА ГОДИНА: #{current_year}

        ПРАВИЛА ЗА ДАТИ:
        - Месеците на български: януари, февруари, март, април, май, юни, юли, август, септември, октомври, ноември, декември
        - "юли" = July #{current_year} (#{current_year}-07)
        - "август" = August #{current_year} (#{current_year}-08)
        - "2 до 6 юли" = #{current_year}-07-02 до #{current_year}-07-06
        - "03-07 юли" = #{current_year}-07-03 до #{current_year}-07-07
        - "юли 03" = #{current_year}-07-03
        - "от 2 до 6 юли" = #{current_year}-07-02 до #{current_year}-07-06
        - "за периода от 2 до 6 юли" = #{current_year}-07-02 до #{current_year}-07-06
        - "за 4 нощувки от 2 юли" = #{current_year}-07-02 до #{current_year}-07-06 (4 нощувки)
        - Други формати:
          * "03.07 до 07.07" = #{current_year}-07-03 до #{current_year}-07-07 (DD.MM формат)
          * "3-ти до 7-ми юли" = #{current_year}-07-03 до #{current_year}-07-07 (редни числителни)
          * "юлий" = юли (често срещана грешка)
          * "юли м месец" = юли (излишен текст)
          * "15 август 2027" = 2027-08-15 (изрично посочена година)
          * "03/07" = #{current_year}-07-03 (DD/MM формат)
        - Сезони:
          * "лятото" = юни, юли, август
          * "есента" = септември, октомври, ноември
          * "зимата" = декември, януари, февруари
          * "пролетта" = март, април, май
        - Формат за API: ВИНАГИ използвай YYYY-MM-DD

        ПРИМЕРИ:
        - "Има ли свободни стаи за юли 03-07?" → check_availability с starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Има ли свободни стаи за 2 до 6 юли?" → check_availability с starts="#{current_year}-07-02", ends="#{current_year}-07-06"
        - "Имаме ли свободна стая за периода от 2 до 6 юли за 4 нощувки?" → check_availability с starts="#{current_year}-07-02", ends="#{current_year}-07-06"
        - "Свободни стаи за 03.07 до 07.07" → check_availability с starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Наличието за 3-ти до 7-ми юли" → check_availability с starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Свободна стая за 2-6 юлий" → check_availability с starts="#{current_year}-07-02", ends="#{current_year}-07-06"
        - "Има ли стаи за юли м месец?" → check_availability с starts="#{current_year}-07-01", ends="#{current_year}-07-31"
        - "Има ли свободни стаи за юли 2025?" → check_availability с starts="2025-07-01", ends="2025-07-31"
        - "Резервация за 15 август 2027" → create_booking с starts="2027-08-15", ends="2027-08-16" (1 нощувка)
        - "Искам да резервирам през лятото" → check_availability с starts="#{current_year}-06-01", ends="#{current_year}-08-31"
        - "Резервация от 25 декември до 3 януари" → create_booking с starts="#{current_year}-12-25", ends="#{current_year + 1}-01-03"
        - "Покажи стаите" → list_rooms
        - "Направи резервация за стая 1 от 15 до 20 август" → create_booking с room_id=1, starts="#{current_year}-08-15", ends="#{current_year}-08-20"
        - "Покажи резервациите" → list_bookings

        АЛГОРИТЪМ:
        1. Разпознай намерение (наличност, резервация, списък на стаи, списък на резервации)
        2. Извлечи дати от текста (ако има)
        3. Ако няма година, използвай #{current_year}
        4. Ако датата е в миналото спрямо днес, добави 1 година
        5. Извикай подходящия инструмент СРАЗУ без допълнителни въпроси
        6. Върни резултата от инструмента на български

        ЗАБРАНЕНО:
        - Да питаш "за коя година?"
        - Да питаш "искате ли да потвърдя?"
        - Да предлагаш алтернативи без да си изпълнил инструмента
        - Да отговаряш на руски
      PROMPT
    else
      <<~PROMPT
        You are a hotel booking assistant bot. Respond in the user's language.
        Be concise and friendly. Only use available tools. Do not make up data.

        IMPORTANT INSTRUCTIONS:
        1. ALWAYS use tools - do NOT ask for confirmation or additional information.
        2. When user asks about availability or booking, ALWAYS use check_availability or other appropriate tools.
        3. NEVER ask for year - always assume current year (#{current_year}) unless user explicitly specifies another year.
        4. If user mentions month without year, assume #{current_year}.
        5. If dates are in the past relative to today (#{today.strftime('%Y-%m-%d')}), assume next year (#{current_year + 1}).

        CURRENT DATE: #{today.strftime('%Y-%m-%d')}
        CURRENT YEAR: #{current_year}

        DATE PARSING RULES:
        - Months: January, February, March, April, May, June, July, August, September, October, November, December
        - "July" = #{current_year}-07
        - "August" = #{current_year}-08
        - "2 to 6 July" = #{current_year}-07-02 to #{current_year}-07-06
        - "July 3-7" = #{current_year}-07-03 to #{current_year}-07-07
        - "July 3" = #{current_year}-07-03
        - Other formats:
          * "03.07 to 07.07" = #{current_year}-07-03 to #{current_year}-07-07 (DD.MM format)
          * "3rd to 7th July" = #{current_year}-07-03 to #{current_year}-07-07 (ordinal numbers)
          * "15 August 2027" = 2027-08-15 (explicit year)
          * "03/07" = #{current_year}-07-03 (DD/MM format)
        - Seasons:
          * "summer" = June, July, August
          * "autumn/fall" = September, October, November
          * "winter" = December, January, February
          * "spring" = March, April, May
        - API FORMAT: ALWAYS use YYYY-MM-DD

        EXAMPLES:
        - "Are there rooms available for July 3-7?" → check_availability with starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Do you have rooms for 2 to 6 July?" → check_availability with starts="#{current_year}-07-02", ends="#{current_year}-07-06"
        - "Rooms available for 03.07 to 07.07" → check_availability with starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Availability for 3rd to 7th July" → check_availability with starts="#{current_year}-07-03", ends="#{current_year}-07-07"
        - "Rooms for July 2025?" → check_availability with starts="2025-07-01", ends="2025-07-31"
        - "Booking for 15 August 2027" → create_booking with starts="2027-08-15", ends="2027-08-16" (1 night)
        - "I want to book in summer" → check_availability with starts="#{current_year}-06-01", ends="#{current_year}-08-31"
        - "Reservation from December 25 to January 3" → create_booking with starts="#{current_year}-12-25", ends="#{current_year + 1}-01-03"
        - "Show me rooms" → list_rooms
        - "Make a booking for room 1 from August 15-20" → create_booking with room_id=1, starts="#{current_year}-08-15", ends="#{current_year}-08-20"
        - "List bookings" → list_bookings

        ALGORITHM:
        1. Recognize intent (availability, booking, list rooms, list bookings)
        2. Extract dates from text (if any)
        3. If no year, use #{current_year}
        4. If date is in the past compared to today, add 1 year
        5. Call appropriate tool IMMEDIATELY without additional questions
        6. Return tool result in user's language

        FORBIDDEN:
        - Asking "which year?"
        - Asking "would you like to confirm?"
        - Offering alternatives without executing tool first
      PROMPT
    end
  end
end
