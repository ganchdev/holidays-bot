# frozen_string_literal: true

FROM ruby:3.3.5-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y sqlite3 libsqlite3-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["bundle", "exec", "ruby", "bot.rb"]
