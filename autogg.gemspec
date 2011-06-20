spec = Gem::Specification.new do |s|
  s.name     = 'autogg'
  s.summary  = 'converts a folder of flacs to ogg, preserving directory structure'
  s.description = File.read(File.join(File.dirname(__FILE__), 'README'))
  s.requirements << 'oggenc must be installed on the base system'
  s.add_dependency 'rb-inotify', '>= 0.8.4'
  s.version  = "0.2.2"
  s.author   = 'Evan Simmons'
  s.email    = 'esims89@gmail.com'
  s.homepage = 'https://github.com/estk/autogg'
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>=1.9'
  s.files    = Dir['**/**']
  s.executables = [ 'autogg' ]
  s.has_rdoc = false
end
