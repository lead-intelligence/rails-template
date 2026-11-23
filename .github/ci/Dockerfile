# syntax=docker/dockerfile:1
# The image CI runs in (.github/workflows/ci.yml), published by
# .github/workflows/ci-image.yml: production's Debian and libvips (Dockerfile),
# the tools the tests use and the template's gems already built, so a run only
# installs the gems its app changed.

# From .ruby-version (ci-image.yml)
ARG RUBY_VERSION
FROM docker.io/library/ruby:$RUBY_VERSION-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential chromium curl file fonts-liberation git libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# The checkout belongs to another user than the container's root: git refuses
# it, and the tests that list the tracked files find none.
RUN git config --system --add safe.directory '*'

# charco_mobile is private and the image can be public: Bundler reads the gem
# with a build secret, then its code leaves the image, and each run fetches it.
COPY Gemfile Gemfile.lock /tmp/bundle/
RUN --mount=type=secret,id=BUNDLE_GITHUB__COM,env=BUNDLE_GITHUB__COM \
    cd /tmp/bundle && bundle install --jobs 4 && \
    rm -rf /tmp/bundle /usr/local/bundle/cache /usr/local/bundle/bundler/gems/charco_mobile-* /usr/local/bundle/bin/charco_mobile
