#!/usr/bin/env ruby

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.


require 'optparse'
require 'ostruct'
require 'find'
#require 'rb-inotify' only when --watch is passed

# Comandline argument parsing function ----
class Parser
  def self.parse(args)

    script_name = File.basename( $0 )
    dirinfo = "Please use absolute paths"
    options = OpenStruct.new
    options.watch = false
    options.max_procs = 4
    options.oggargs = []

    op = OptionParser.new do |opts|
      opts.banner = "Usage: autogg.rb [options] flacpath oggpath [ -o oggenc args ... ]\n" +
                    "Example: #{script_name} ~/music/flac/ ~music/ogg/ --watch --oggenc-args BLAH"

      opts.on( '-w', '--watch',
              "Watch flacpath for changes, then rescan " +
              "and encode if any files are created within" ) do
        options.watch = true
      end

      opts.on( '-m', '--max-processes n', "Maximum number of encoding processes running at once" ) do |n|
        options.max_procs = n.to_i if n
      end

      opts.on( '-o', '--oggenc-args arglist', Array,
               "Specify arguments to me be passed through to oggenc" ) do |ary|
        options.oggargs = ary unless ary.empty?
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        puts dirinfo
      end
    end

    op.parse!

    if ( ARGV.length == 2 ) and ARGV.all? { |a| File.directory?( a )}
      paths = OpenStruct.new
      paths.flac = ARGV[0] ; paths.ogg = ARGV[1]
      options.paths = paths
    else
      puts op
      exit
    end

    options
  end
end

# class definitions ----------------- DONE

class Flac < File
  def self.exists?( path )
    file?( path ) and basename( path ) =~ /\.flac/
  end
end

class Ogg < File
  def self.exists?( path )
    file?( path ) and basename( path ) =~ /\.ogg/
  end
end

class SizedPsHash < Hash
  ## Takes pids as keys and paths to the
  ## corresponding files the ps is encoding as values.
  ## Blocks until (its hash) size less than @max to add a new process.
  ## Automatically removes completed processes.

  def initialize( max )
    @max = max
    super
  end

  def []=( pid, path )
    puts self
    while size >= @max
      pid = Process.wait
      delete( pid )
    end
    super( pid, path )
  end
end

class OggEncoder
  class << self

    def oggencdir
      Find.find( @paths.flac ) do |path|
        puts "checking #{path}"
        if FileTest.directory?( path )
          Find.prune if File.basename( path )[0] == ?.
        elsif Flac.exists?( path ) and not Ogg.exists?( getoutpath(path) )
          encfile( path )
        end
      end
    end

    def encfile( inpath )
      outpath = getoutpath( inpath )
      ps = IO.popen %Q{oggenc #{@oggargs.join} "#{inpath}" -o "#{outpath}"}
      @ps_hash[ps.pid] = outpath
    end

    def getoutpath( inpath )
      outpath = inpath.gsub( @paths.flac, @paths.ogg )
      outpath.gsub!( /\.flac/, '.ogg' )
    end

    def interupt
      puts "\n" + "Shutting down and removing partially encoded files"
      @ps_hash.each do |pid, path|
        File.delete( path )
      end
      exit
    end

    def watcher
      ##INCOMPLETE
      ## needs separate interupt signal handling
      notifier = INotify::Notifier.new
      notifier.watch( @flacpath, :create ) do |e|
        puts e.name + " was modified, rescaning..."
        oggencdir ; Process.waitall
      end
      puts "watching #{@flacpath}"
      notifier.run
    end

    def encode( options )
      @options = options
      @paths = options.paths
      @oggargs = options.oggargs
      @ps_hash = SizedPsHash.new( options.max_procs )
      oggencdir ; Process.waitall
      watcher if options.watch
    end
  end

  trap "INT" do
    interupt
  end
end

if __FILE__ == $0
  options = Parser.parse( ARGV )
  OggEncoder.encode( options )
end

## TODO
# 1. test
# - a progress bar would be nice
# - any chance of changing all dirs in oggpath from containing /\flac/i to /ogg/i ?
