require 'sidekiq'
require 'rgeo'
require 'rgeo-geojson'
require 'benchmark'

# =============================
# LMILookup class here
# ...
# =============================

class TestJob
  include Sidekiq::Worker
  sidekiq_options queue: 'test_queue', retry: 0

  def perform(state, latitude, longitude)
    LMILookup.new(state).lmi_zones(latitude, longitude)

    GC.start # force garbage collection
  end
end

Sidekiq.redis(&:flushdb) # remove any junk
Sidekiq.logger.level = Logger::DEBUG # set log level

# system memory profiling
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

sleep(1) # wait a moment

total = (ENV['TOTAL'] || 10).to_i

%w[AK AL AR AZ CA CO CT DE FL GA HI IA ID IL IN KS DC KY LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY].each do |state|
  total.times do
    latitude = rand(30.7128..50.7128)
    longitude = rand(-84.0060..-64.0060)
    TestJob.perform_async(state, latitude, longitude)
  end
end

puts "C API available?: #{RGeo::Geos.capi_supported? }"
