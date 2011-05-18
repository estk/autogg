#!/usr/bin/env ruby

#require 'rb-inotify' only when --watch is passed
require 'optparse'


IGNORE = [ '.', '..' ]

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.

def parseargs
  options = []
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
end

#main mutural recursion loop-----------

def oggencdir( path )
  Dir.new( @flacpath + path ).each do |f|

    input  = @flacpath + path + f
    output = @oggpath  + path + f.gsub( /\.flac/, '.ogg' )

    if ignored?( f )
      next

    elsif File::directory?( input )
      dirhelper( path + f )

    elsif File.exists?( output ) ; next

    elsif flac?( f )
      encfile( input, output ) if fork.nil?
    end
  end
end

def dirhelper( path )
  Process.waitall

  if File::directory?( @oggpath + path )
    oggencdir( path + '/' )

  else
    Dir.mkdir( @oggpath + path )
    oggencdir( path + '/' )
  end
end

#end mainloop-----------------------

def encfile( input, output )
  exec %Q{oggenc #{@oggargs.join} "#{input}" -o "#{output}"}
end

def flac?( file )
  file =~ /\.flac/
end

def ignored?( file )
  IGNORE.find { |i| file == i }
end

def interupt
 puts "\n" + "Shutting down, must complete encodes in current dir first though"
 Process.waitall
 exit
end

trap "INT" do
 interupt
end

if __FILE__ == $0
  parseargs
  oggencdir ''
  Process.waitall

  if options[:watch]
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
