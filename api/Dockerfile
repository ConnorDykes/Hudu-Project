# Optional local development API. Publish port 3000 to 127.0.0.1 on the host.
FROM ruby:4.0.2-slim

WORKDIR /rails
ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev libsqlite3-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle config set frozen true && bundle install

COPY . .
RUN chmod +x bin/docker-entrypoint && mkdir -p storage tmp/pids log

VOLUME /rails/storage
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
