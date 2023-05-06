# bundle exec puma -C config/puma.rb
workers 2
threads 2, 4

preload_app!

port 3000
environment 'development'
worker_timeout 1000000
