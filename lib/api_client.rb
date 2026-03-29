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

  def rooms(token: nil)
    authenticated_get('/api/v1/rooms', token: token)
  end

  def availability(starts:, ends:, token: nil)
    authenticated_get(
      '/api/v1/availability',
      params: { starts: starts, ends: ends },
      token: token
    )
  end

  def guests(search:, token: nil)
    authenticated_get(
      '/api/v1/guests',
      params: { search: search },
      token: token
    )
  end

  def bookings(params = {}, token: nil)
    query = params.compact
    authenticated_get('/api/v1/bookings', params: query, token: token)
  end

  def booking(id, token: nil)
    authenticated_get("/api/v1/bookings/#{id}", token: token)
  end

  def create_booking(params, token: nil)
    authenticated_post('/api/v1/bookings', params.compact, token: token)
  end

  def update_booking(id, params, token: nil)
    authenticated_patch("/api/v1/bookings/#{id}", params.compact, token: token)
  end

  private

  def authenticated_get(path, params: {}, token: nil)
    headers = auth_headers(token)
    response = HTTP.headers(headers).get("#{BASE_URL}#{path}", params: params)
    parse_response(response)
  rescue StandardError => e
    { 'error' => e.message }
  end

  def authenticated_post(path, params, token: nil)
    headers = auth_headers(token)
    response = HTTP.headers(headers).post("#{BASE_URL}#{path}", json: params)
    parse_response(response)
  rescue StandardError => e
    { 'success' => false, 'error' => e.message }
  end

  def authenticated_patch(path, params, token: nil)
    headers = auth_headers(token)
    response = HTTP.headers(headers).patch("#{BASE_URL}#{path}", json: params)
    parse_response(response)
  rescue StandardError => e
    { 'success' => false, 'error' => e.message }
  end

  def auth_headers(token)
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token
    headers
  end

  def parse_response(response)
    body = response.body.to_s
    raise "API error: #{response.status} - #{body[0..200]}" unless response.status.success?

    JSON.parse(body)
  rescue JSON::ParserError
    raise "Invalid JSON from API: #{body[0..200]}"
  end
end
