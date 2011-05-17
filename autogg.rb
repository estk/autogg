#!/usr/bin/env ruby

#require 'rb-inotify' only when --watch is passed


FLACD = '/media/tb/rt/wt/'
OGGD  = '/media/tb/ogg/'
IGNORE = [ '.', '..' ]
USAGE = "usage: ~$ ./autogg.rb [--watch] [flacpath oggpath] " +
        "[--opts n oggenc args] \n" +
        "uses -q8 by default, --help prints this message \n" +

"flacpath and oggpath are optional, though if you define one, \
you need to define the other. And if you don't define them, \
make sure to edit this script to reflect your flacpath and \
oggpath. Lastly, use absolute paths"

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.

@watchflag = false
@readyflag = false
@oggargs = []
@args = []


class BadArgvs < StandardError; end

def setup
  case ARGV[0]
  when '--help'; raise BadArgvs
  when '--watch'
    require 'rb-inotify'
    @watchflag = true
    ARGV[1..-1].each do |e| @args << e end
  end

  @args = ARGV unless @watchflag

  if @args.empty?
      @flacpath = FLACD
      @oggpath  = OGGD

  elsif @args.length == 1
      raise BadArgvs

  elsif @args.length == 2
      @flacpath = @args[0]
      @oggpath  = @args[1]

  elsif @args[2] == '--opts'
      @flacpath = @args[0]
      @oggpath  = @args[1]
      @oggargs  = @args[3..-1]

  else
      raise BadArgvs
  end

rescue BadArgvs
  puts USAGE
  exit
end

@oggargs << '-q8' unless @oggargs.find { |e| /-q\d/ }

def oggencdir( path )
  Dir.new( @flacpath + path ).each do |f|

    input  = @flacpath + path + f
    output = @oggpath  + path + f.gsub( /\.flac/, '.ogg' )

    if ignored?( f ) or File.exists?( output )
      next

    elsif File::directory?( input )
      dirhelper( path + f )

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

def encfile( input, output )
  exec %Q{oggenc #{@oggargs.join} "#{input}" -o "#{output}"}
end

def flac?( file )
  file =~ /\.flac/
end

def ignored?( file )
  IGNORE.find { |i| file == i }
end

if __FILE__ == $0
  setup
  oggencdir ''
  Process.waitall

  if @watchflag
    # wait for changes via inotify
    notifier = INotify::Notifier.new

    notifier.watch( FLACD, :create ) do |e|
      puts e.name + " was modified, rescaning..."
      oggencdir( '' )
      Process.waitall
    end

    notifier.run
  end
end
