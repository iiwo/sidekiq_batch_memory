## Overview

Test script for profiling memory usage

### Usage

install gems
```shell
bundle install
```

run sidekiq test
```shell
NUMBER_OF_JOBS=100000 bundle exec sidekiq -c 1 -r ./test_mem.rb -q test_queue
```

### Results

![Screen Shot 2021-01-04 at 5 04 31 PM](https://user-images.githubusercontent.com/994762/103555380-750e1580-4eb0-11eb-8d9d-8c3732757485.png)


### Related read
https://github.com/mperham/sidekiq/wiki/Batches
https://github.com/mperham/sidekiq/wiki/Bulk-Queueing
https://github.com/mperham/sidekiq/issues/4202
https://github.com/mperham/sidekiq/issues/2023

