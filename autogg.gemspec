require 'rake/gempackagetask'
spec = Gem::Specification.new do |s|
  s.name     = 'autogg'
  s.summary  = File.read(File.join(File.dirname(__FILE__), 'README'))
  s.requirements << 'oggenc must be installed on the base system'
  s.version  = "0.1.0"
  s.author   = 'Evan Simmons'
  s.email    = 'esims89@gmail.com'
  s.homepage = 'https://github.com/estk/autogg'
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>=1.9'
  s.files    = Dir['**/**']
  s.executables = [ 'autogg' ]
  s.has_rdoc = false
end
Rake::GemPackageTask.new(spec).define
