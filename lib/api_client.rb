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
    parse_response(response)
  rescue StandardError => e
    { 'success' => false, 'error' => e.message }
  end

  def rooms
    response = HTTP.get("#{BASE_URL}/api/v1/rooms")
    parse_response(response)
  rescue StandardError => e
    { 'rooms' => [], 'error' => e.message }
  end

  def availability(starts:, ends:)
    response = HTTP.get(
      "#{BASE_URL}/api/v1/availability",
      params: { starts: starts, ends: ends }
    )
    parse_response(response)
  rescue StandardError => e
    { 'available' => [], 'error' => e.message }
  end

  def guests(search:)
    response = HTTP.get(
      "#{BASE_URL}/api/v1/guests",
      params: { search: search }
    )
    parse_response(response)
  rescue StandardError => e
    { 'guests' => [], 'error' => e.message }
  end

  def bookings(params = {})
    query = params.compact
    response = HTTP.get("#{BASE_URL}/api/v1/bookings", params: query)
    parse_response(response)
  rescue StandardError => e
    { 'bookings' => [], 'error' => e.message }
  end

  def booking(id)
    response = HTTP.get("#{BASE_URL}/api/v1/bookings/#{id}")
    parse_response(response)
  rescue StandardError => e
    { 'booking' => nil, 'error' => e.message }
  end

  def create_booking(params)
    response = HTTP.post(
      "#{BASE_URL}/api/v1/bookings",
      json: params.compact
    )
    parse_response(response)
  rescue StandardError => e
    { 'success' => false, 'error' => e.message }
  end

  def update_booking(id, params)
    response = HTTP.patch(
      "#{BASE_URL}/api/v1/bookings/#{id}",
      json: params.compact
    )
    parse_response(response)
  rescue StandardError => e
    { 'success' => false, 'error' => e.message }
  end

  private

  def parse_response(response)
    body = response.body.to_s
    raise "API error: #{response.status} - #{body[0..200]}" unless response.status.success?

    JSON.parse(body)
  rescue JSON::ParserError
    raise "Invalid JSON from API: #{body[0..200]}"
  end
end
