# frozen_string_literal: true

require 'sqlite3'

class Database
  DB_PATH = File.join(__dir__, '..', 'db', 'bot.db')

  def initialize
    ensure_schema
  end

  def get_session(chat_id)
    db.execute(
      'SELECT * FROM sessions WHERE chat_id = ?',
      [chat_id.to_s]
    ).first
  end

  def save_session(chat_id, user_id, user_name, user_email, token = nil)
    db.execute(
      <<~SQL,
        INSERT OR REPLACE INTO sessions (chat_id, user_id, user_name, user_email, token, last_active_at)
        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      SQL
      [chat_id.to_s, user_id, user_name, user_email, token]
    )
  end

  def update_token(chat_id, token)
    db.execute(
      'UPDATE sessions SET token = ?, last_active_at = CURRENT_TIMESTAMP WHERE chat_id = ?',
      [token, chat_id.to_s]
    )
  end

  def delete_session(chat_id)
    db.execute('DELETE FROM sessions WHERE chat_id = ?', [chat_id.to_s])
  end

  def update_language(chat_id, language)
    db.execute(
      'UPDATE sessions SET language = ?, last_active_at = CURRENT_TIMESTAMP WHERE chat_id = ?',
      [language, chat_id.to_s]
    )
  end

  def set_pending_verification(chat_id, email)
    db.execute(
      'INSERT OR REPLACE INTO pending_verifications (chat_id, email) VALUES (?, ?)',
      [chat_id.to_s, email]
    )
  end

  def get_pending_verification(chat_id)
    db.execute(
      'SELECT * FROM pending_verifications WHERE chat_id = ?',
      [chat_id.to_s]
    ).first
  end

  def delete_pending_verification(chat_id)
    db.execute('DELETE FROM pending_verifications WHERE chat_id = ?', [chat_id.to_s])
  end

  private

  def db
    @db ||= SQLite3::Database.new(DB_PATH).tap { |d| d.results_as_hash = true }
  end

  def ensure_schema
    schema_path = File.join(__dir__, '..', 'db', 'schema.sql')
    db.execute_batch(File.read(schema_path))
  end
end
