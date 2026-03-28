# frozen_string_literal: true

require 'http'
require 'json'

class ApiClient
  BASE_URL = ENV.fetch('RAILS_API_URL', 'http://localhost:3000')

  def verify(chat_id, code)
    response = HTTP.post(
      "#{BASE_URL}/api/v1/auth/verify",
      json: { chat_id: chat_id, code: code }
    )
    JSON.parse(response.body)
  end

  def rooms
    response = HTTP.get("#{BASE_URL}/api/v1/rooms")
    JSON.parse(response.body)
  end

  def availability(starts:, ends:)
    response = HTTP.get(
      "#{BASE_URL}/api/v1/availability",
      params: { starts: starts, ends: ends }
    )
    JSON.parse(response.body)
  end

  def guests(search:)
    response = HTTP.get(
      "#{BASE_URL}/api/v1/guests",
      params: { search: search }
    )
    JSON.parse(response.body)
  end

  def bookings(params = {})
    query = params.compact
    response = HTTP.get("#{BASE_URL}/api/v1/bookings", params: query)
    JSON.parse(response.body)
  end

  def booking(id)
    response = HTTP.get("#{BASE_URL}/api/v1/bookings/#{id}")
    JSON.parse(response.body)
  end

  def create_booking(params)
    response = HTTP.post(
      "#{BASE_URL}/api/v1/bookings",
      json: params.compact
    )
    JSON.parse(response.body)
  end

  def update_booking(id, params)
    response = HTTP.patch(
      "#{BASE_URL}/api/v1/bookings/#{id}",
      json: params.compact
    )
    JSON.parse(response.body)
  end
end
