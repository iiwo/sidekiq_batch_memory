require 'sidekiq'
require "sidekiq/pro/worker"
require 'sidekiq/pro/api'
require "sidekiq/pro/push"
require "sidekiq/pro/metrics"
require 'sidekiq/batch'
require 'sidekiq_profiling_middleware/memory_profiler'

NUMBER_OF_JOBS = (ENV['NUMBER_OF_JOBS'] || 50_000).to_i

class AtomicJob
  include Sidekiq::Worker
  sidekiq_options queue: 'test_queue', retry: 0

  def perform(account_id)
    #raise 'test error' if account_id.to_s == '49999' # simulate error if needed
  end
end

class BatchJob
  include Sidekiq::Worker
  sidekiq_options queue: 'test_queue', retry: 0

  class BatchCallback
    def on_complete(status, options)
      puts "FINISHED ALL JOBS: running garbage collection"
      GC.start # force garbage collection after finish
    end
  end

  def perform
    batch = Sidekiq::Batch.new
    batch.on(:complete, BatchCallback)
    batch.jobs do
      # AFTER (using bulk)
      #
      (1..NUMBER_OF_JOBS).to_a.each_slice(1000) do |batch|
        account_id_batch = batch.map {|id| [id] }
        Sidekiq::Client.push_bulk('class' => AtomicJob, 'args' => account_id_batch)
      end

      # BEFORE (atomic)
      #
      # (1..NUMBER_OF_JOBS).each do |account_id|
      #   AtomicJob.perform_async(account_id)
      # end
    end
  end
end

Sidekiq.redis(&:flushdb) # remove any junk
Sidekiq.logger.level = Logger::DEBUG # set log level

# enabling memory profiler will affect process memory
if ENV['MEMORY_PROFILER']
  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add SidekiqProfilingMiddleware::MemoryProfiler, output_prefix: "sidekiq_mem_", only: [BatchJob].to_set
    end
  end
end

# system memory profiling
if ENV['SYSTEM_MEMORY']
  Thread.new do
    require 'csv'

    Dir.mkdir(save_to) rescue true
    file = "#{ENV['FILE_NAME'] || 'sidekiq_mem'}.csv"

    CSV.open(file, 'wb') do |csv|
      while true do
        rsize, _name = `ps ax -o rss,command | grep -E "[s]idekiq(.+)of 1 busy]"`.split(/\n/).map{ |p| p.split(' ', 2) }.sort_by{|a| a[0].to_i}.last
        csv << [rsize.to_i]
        sleep(0.2)
        Thread.pass
      end
      Thread.exit
    end
  end
end

sleep(1) # wait a moment for system memory values
BatchJob.perform_at(Time.now) # run batch job
