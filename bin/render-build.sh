#!/usr/bin/env bash
# exit on error
set -o errexit

# Install ImageMagick
apt-get update -qq && apt-get install -y -qq imagemagick

# Install gems
bundle install

# Precompile assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Run migrations
bundle exec rails db:migrate