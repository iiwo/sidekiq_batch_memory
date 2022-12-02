require 'sidekiq'
require 'sidekiq-unique-jobs'

NUMBER_OF_JOBS = (ENV['NUMBER_OF_JOBS'] || 50_000).to_i

class TestJob
  include Sidekiq::Worker
  if ENV['WITH_UNIQUE']
    sidekiq_options queue: 'test_queue', lock: :until_executed, on_conflict: nil
  else
    sidekiq_options queue: 'test_queue'
  end

  def perform(_identifier)
    sleep(0.1) # simulate job processing time
  end
end

Sidekiq.redis(&:flushdb) # remove any junk
Sidekiq.logger.level = Logger::DEBUG # set log level

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

# profiling
Thread.new do
  require 'csv'

  Dir.mkdir(save_to) rescue true
  file = ENV['FILE_NAME'] || 'redis_stats.csv'

  CSV.open(file, 'wb') do |csv|
    info = Sidekiq.redis(&:info)
    csv << ['time', 'locks count', 'jobs count'] + info.keys
    while true do
      info = Sidekiq.redis(&:info)
      locks_count, _a, _b = SidekiqUniqueJobs::Digests.new.page
      jobs_count = Sidekiq::Queue.new('test_queue').count
      csv << [Time.now.to_i, locks_count, jobs_count] + info.values
      sleep(0.2)
      Thread.pass
    end
    Thread.exit
  end
end

sleep(1) # wait a moment

total = (ENV['TOTAL'] || 10_000).to_i
ratio = (ENV['RATIO'] || 0.1).to_f

raise 'ratio must be 0..1' unless (0..1).cover?(ratio)

max = (1 - ratio) * total
max = max < 1 ? 1 : max
sum = 0

(total/max).ceil.times do
  count = [max, total - sum].min
  sum += count
  (1..count).to_a.each do |identifier|
    TestJob.perform_async(identifier)
  end
end
