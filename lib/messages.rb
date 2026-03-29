# frozen_string_literal: true

class Messages
  MESSAGES = {
    en: {
      welcome: 'Hello %{name}! I\'m your hotel booking assistant. How can I help you today?',
      help: "Available commands:\n/start - Start the bot\n/login - Log in with your email\n/logout - Log out\n/help - Show this message",
      login_prompt: 'Please enter your email address to log in:',
      login_link: "Open this link in your browser:\n%{link}\n\nThen come back and enter the 6-digit code you see.",
      not_authenticated: 'Please log in first using /login',
      logged_out: "You've been logged out. Use /login to log in again.",
      login_success: 'Welcome, %{name}! You\'re now logged in.',
      invalid_code: 'Invalid or expired code. Please try /login again.',
      invalid_email: 'Invalid email format. Please enter a valid email address.',
      error: 'Something went wrong. Please try again.',
      processing: 'Let me check that for you...'
    },
    bg: {
      welcome: 'Здравей %{name}! Аз съм хотелският асистент. Как мога да ти помогна?',
      help: "Налични команди:\n/start - Стартирай бота\n/login - Вход с имейл\n/logout - Изход\n/help - Покажи това съобщение",
      login_prompt: 'Моля, въведи имейл адреса си за вход:',
      login_link: "Отвори този линк в браузъра си:\n%{link}\n\nСлед това се върни тук и въведи 6-цифрения код, който виждаш.",
      not_authenticated: 'Моля, първо влез с /login',
      logged_out: 'Излязъл си. Използвай /login за да влезеш отново.',
      login_success: 'Добре дошъл, %{name}! Вече си влязъл.',
      invalid_code: 'Невалиден или изтекъл код. Моля, опитай с /login отново.',
      invalid_email: 'Невалиден имейл формат. Моля, въведи валиден имейл адрес.',
      error: 'Нещо се обърка. Моля, опитай отново.',
      processing: 'Проверявам...'
    }
  }.freeze

  def initialize
    @language = :bg
  end

  def language=(lang)
    @language = lang == 'bg' ? :bg : :en
  end

  def t(key, **params)
    msg = MESSAGES[@language][key]
    format(msg, params)
  end

  def welcome(update)
    name = update.from.first_name || 'Guest'
    t(:welcome, name: name)
  end

  def login_prompt
    t(:login_prompt)
  end

  def login_link(email, chat_id)
    link = "#{ENV.fetch('RAILS_API_URL', 'http://localhost:3000')}/bot_verify?chat_id=#{chat_id}&email=#{email}"
    t(:login_link, link: link)
  end

  def not_authenticated
    t(:not_authenticated)
  end

  def logged_out
    t(:logged_out)
  end

  def login_success(name)
    t(:login_success, name: name)
  end

  def invalid_code
    t(:invalid_code)
  end

  def invalid_email
    t(:invalid_email)
  end

  def help
    t(:help)
  end

  def error
    t(:error)
  end

  def processing
    t(:processing)
  end
end
