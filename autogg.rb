#!/usr/bin/env ruby

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.

#require 'rb-inotify' only when --watch is passed
require_relative 'progressbar'
require 'optparse'
require 'ostruct'
require 'find'

class Parser
  def self.parse(args)

    script_name = File.basename( $0 )
    options = OpenStruct.new
    options.watch = false
    options.max_procs = 4
    options.oggargs = ['-Q']

    op = OptionParser.new do |opts|
      opts.banner = "Usage: autogg.rb [options] flacpath oggpath [ -o oggenc args ... ]\n" +
                    "Example: #{script_name} ~/music/flac/ ~/music/ogg/ --watch --oggenc-args -q8\n" +
                    "    Ex2: #{script_name} ~/music/flac/ ~/music/ogg/ -o -q8,-Q,--utf8"

      opts.on( '-w', '--watch',
              "Watch flacpath for changes, then rescan " +
              "and encode if any files are created within" ) do
        options.watch = true
      end

      opts.on( '-m', '--max-processes n', "Maximum number of encoding processes running at once" ) do |n|
        options.max_procs = n.to_i
      end

      opts.on( '-o', '--oggenc-args arglist', Array,
               "Specify arguments to me be passed through to oggenc" ) do |ary|
        options.oggargs << ary
        options.oggargs.flatten!
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        puts dirinfo
        exit
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

  def initialize( max )
    @max = max
    super
  end

  def store( pid, path, &block )
    while size >= @max
      pid = Process.wait
      delete( pid )
    end
    ps = block.call
    super( ps.pid, path )
  end
end

class OggEncoder
  class << self

    def oggencdir
      Find.find( @paths.flac ) do |path|
        if FileTest.directory?( path )
          if File.basename( path )[0] == ?.
            Find.prune
          else
            #@pbar.inc
          end
        elsif Flac.exists?( path ) and not Ogg.exists?( getoutpath(path) )
          encfile( path )
          @pbar.inc
        end
      end
      Process.waitall
    end

    def encfile( inpath )
      outpath = getoutpath( inpath )
      @ps_hash.store( nil, outpath ) do
        IO.popen %Q{oggenc #{@oggargs.join(' ')} "#{inpath}" -o "#{outpath}"}
      end
    end

    def getoutpath( inpath )
      outpath = inpath.gsub( @paths.flac, @paths.ogg )
      outpath.gsub!( /\.flac/, '.ogg' )
    end

    def count_flacs
      counter = 0
      Find.find( @paths.flac ) {|p| counter += 1 if Flac.exists?( p ) }
      counter
    end

    def interupt
      puts "\n" + "Shutting down and removing partially encoded files"
      @ps_hash.each do |pid, path|
        File.delete( path )
      end
      exit
    end

    def watcher
      require 'rb-inotify'
      notifier = INotify::Notifier.new
      notifier.watch( @paths.flac, :create ) do |e|
        puts %Q{#{Time.now.ctime}:  #{e.name} was modified, rescaning...}
        oggencdir ; Process.waitall
        puts "watching #{@paths.flac}"
      end
      puts "watching #{@paths.flac}"
      notifier.run
    end

    def encode( options )
      @options = options
      @paths = options.paths
      @oggargs = options.oggargs
      @ps_hash = SizedPsHash.new( options.max_procs )
      @pbar = ProgressBar.new( "Subdirectory progress", count_flacs )
      oggencdir ; @pbar.finish
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
