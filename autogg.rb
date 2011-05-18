#!/usr/bin/env ruby

#require 'rb-inotify' only when --watch is passed
require 'optparse'
require 'find'
#require 'thread'

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.

def parseargs
  options = {}
  dirinfo = "Please use absolute paths"

  op = OptionParser.new do |opts|
    opts.banner = "Usage: autogg.rb [options] flacpath oggpath [ -o oggenc args ... ]"

    options[:watch] = false
    opts.on( '-w', '--watch', 
            "Watch flacpath for changes, then rescan " +
            "and encode if any files are created within" ) do
      options[:watch] = true
    end

    options[:oggargs] = false
    opts.on( '-o', '--oggenc-args', 
             "Specify arguments to me be passed " +
             "through to each oggenc" ) do
      options[:oggargs] = true
    end

    opts.on( '-h', '--watch', 'Display this screen' ) do
      puts opts
      puts dirinfo
    end
  end.parse!

  if ( ARGV[0..1].all? { |a| a =~ /\/.*\// } )
    @flacpath, @oggpath = ARGV[0..1]
  else
    puts dirinfo
  end

  if options[:oggargs]
    @oggargs = ARGV[2..-1]
  else
    @oggargs = []
  end

  @watchflag = options[:watch]
end

#yay monkeypatching

class File
  class << self
    def flac?(path)
      self.file?(path) and self.basename(path) =~ /\.flac/
    end
  end
end

# find refactorization --------

thread_hash = {}

def oggencdir
  Find.find(ENV["HOME"]) do |path|
    if FileTest.directory?( path )
      Find.prune if File.basename(path)[0] == ?.
    elsif File.flac?( path )
      encfile( path )
    end
  end
end


# small helpers-----------------

def encfile( input )
  output = input.gsub( @flacpath, @oggpath )
  exec %Q{oggenc #{@oggargs.join} "#{input}" -o "#{output}"}
end

def interupt
  puts "\n" + "Shutting down and removing partially encoded files in #{@cwd}"
end

# end helpers ------------------

trap "INT" do
 interupt
end

if __FILE__ == $0
  parseargs
  oggencdir ''

  Process.waitall

  if @watchflag
    # wait for changes via inotify
    notifier = INotify::Notifier.new

    notifier.watch( @flacpath, :create ) do |e|
      puts e.name + " was modified, rescaning..."
      oggencdir ''
      Process.waitall
    end

    puts "watching #{@flacpath}"
    notifier.run
  end
end
