require 'rake/testtask'

task :default => :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc "Runs sisyphus in the foreground"
task :run do
  exec("bin/thin --port 3001 --max-persistent-conns 1024 --timeout 0 start")
end

desc "Starts sisyphus"
task :start do
  exec("bin/thin --port 3001 -d --max-persistent-conns 1024 --timeout 0 start")
end

desc "Stops sisyphus"
task :stop do
  exec("bin/thin stop")
end
