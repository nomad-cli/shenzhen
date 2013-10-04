require "bundler/setup"

gemspec = eval(File.read("shenzhen.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["shenzhen.gemspec"] do
  system "gem build shenzhen.gemspec"
end
