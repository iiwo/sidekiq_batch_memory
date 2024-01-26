require 'sidekiq'
require 'sidekiq-unique-jobs'

## ===========================
# SETUP
# ============================

$VERBOSE = nil

def red
  "\e[31m"
end

def green
  "\e[32m"
end

def blue
  "\e[34m"
end

def reset
  "\e[0m"
end

def extract_log_from_job(job_hash)
  # worker    = job_hash['class']
  args      = job_hash['args']
  lock_args = job_hash['lock_args']
  # queue     = job_hash['queue']
  "#{red} Lock (conflict) | args: #{args} | lock_args: #{lock_args} #{reset}"
end

SidekiqUniqueJobs.reflect do |on|
  on.lock_failed do |job_hash|
    message = extract_log_from_job(job_hash)
    Sidekiq.logger.warn(message)
  end
end

Sidekiq.redis(&:flushdb) # remove any junk
Sidekiq.logger.level = Logger::INFO # set log level

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

## ===========================
# TEST JOBS
# ============================

class TestJob
  include Sidekiq::Worker
  # queue name needs to match -q option
  sidekiq_options queue: 'test_queue', lock: :until_executed, on_conflict: nil

  def perform(test_arg)
    Sidekiq.logger.info("#{green}running TestJob with arg: #{test_arg}#{reset}")
    sleep(2)
  end
end

## ===========================
# TEST SCENARIOS
# ============================

@@start = false

# enqueueing thread 1
Thread.new do
  while !@@start do; end
  Sidekiq.logger.info("#{blue}enqueuing first job#{reset}")
  TestJob.perform_async('foo') # job
  sleep(0.5)
  Sidekiq.logger.info("#{blue}enqueuing job while the first job is still running#{reset}")
  TestJob.perform_async('foo') # while processing job
  sleep(2)
  Sidekiq.logger.info("#{blue}enqueuing job after the first job finished#{reset}")
  TestJob.perform_async('foo') # 0.5s after processing job
end

# enqueueing thread 2
Thread.new do
  while !@@start do; end
  Sidekiq.logger.info("#{blue}enqueuing simultaneous job in parallel#{reset}")
  TestJob.perform_async('foo') # simultaneous job
  TestJob.perform_async('bar') # simultaneous job with different arguments
end

# synchronize start thread
Thread.new do
  sleep(5) # wait for everything to start
  Sidekiq.logger.info("#{blue}assuming init finished: start enqueuing#{reset}")
  @@start = true # start enqueuing threads
end

Sidekiq.logger.info("#{blue}waiting for initialization to finish#{reset}")

