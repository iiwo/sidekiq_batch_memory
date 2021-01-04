## Overview

Test script for profiling memory usage

### Usage

install gems
```shell
bundle install
```

run system memory profiling
```shell
SYSTEM_MEMORY=true NUMBER_OF_JOBS=100000 bundle exec sidekiq -c 1 -r ./test_mem.rb -q test_queue
```

run memory profiling
```shell
MEMORY_PROFILER=true NUMBER_OF_JOBS=100000 bundle exec sidekiq -c 1 -r ./test_mem.rb -q test_queue
```

### Results

#### BEFORE (atomic)
```ruby
batch = Sidekiq::Batch.new
batch.jobs do
  (1..100_000).each do |account_id|
    AtomicJob.perform_async(account_id)
  end
end
```

#### AFTER (using bulk)
```ruby
batch = Sidekiq::Batch.new
batch.jobs do
  (1..100_000).to_a.each_slice(1000) do |batch|
    account_id_batch = batch.map {|id| [id] }
    Sidekiq::Client.push_bulk('class' => AtomicJob, 'args' => account_id_batch)
  end
end
```

![Screen Shot 2021-01-04 at 9 45 59 PM](https://user-images.githubusercontent.com/994762/103578304-9aae1580-4ed6-11eb-9523-c4d9d0333cf7.png)

### Related read
https://github.com/mperham/sidekiq/wiki/Batches
https://github.com/mperham/sidekiq/wiki/Bulk-Queueing
https://github.com/mperham/sidekiq/issues/4202
https://github.com/mperham/sidekiq/issues/2023

