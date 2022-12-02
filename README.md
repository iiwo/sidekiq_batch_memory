## Overview

Test script for profiling memory usage

### Usage

install gems
```shell
bundle install
```

run system memory profiling
```shell
bundle exec sidekiq -c 1 -r ./test_mem.rb -q test_queue
```
