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
# Run as an unprivileged user. Only the writable runtime paths are owned by it;
# the named volume mounted at /rails/storage inherits this ownership on first use.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chmod +x bin/docker-entrypoint && mkdir -p storage tmp/pids tmp/cache log && \
    chown -R rails:rails storage tmp log db
USER 1000:1000

VOLUME /rails/storage
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
