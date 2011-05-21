#!/usr/bin/env ruby

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.


require 'optparse'
require 'find'
#require 'rb-inotify' only when --watch is passed

# Comandline argument parsing function ----

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

    options[:oggargs] = nil
    opts.on( '-o', '--oggenc-args', 
             "Specify arguments to me be passed " +
             "through to each oggenc" ) do
      options[:oggargs] = true
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      puts dirinfo
    end
  end

  op.parse!

  if ( ARGV.length >= 2 ) and ( ARGV[0..1].all? { |a| a =~ /\/.*\// } )
    @flacpath, @oggpath = ARGV[0..1]
  else
    puts op
    exit
  end

  if options[:oggargs]       ## maybe there is a beter way to parse oggargs?
    @oggargs = ARGV[2..-1]
  else
    @oggargs = []
  end
end

# directory traversal ------ DONE

def oggencdir
  @ps_hash = SizedPsHash.new(4)
  Find.find( @flacpath ) do |path|
    if FileTest.directory?( path )
      Find.prune if File.basename( path )[0] == ?.
    elsif File.flac?( path )
      encfile( path )
    end
  end
end


# class definitions ----------------- DONE

class File
  def self.flac?(path)
    self.file?(path) and self.basename(path) =~ /\.flac/
  end
end

class SizedPsHash < Hash
  ## Takes pids as keys and paths to the
  ## corresponding files the ps is encoding as values.
  ## Blocks until (its hash) size less than @max to add a new process.
  ## Automatically removes completed processes.

  def self.initialize(max)
    @max = max
    super
  end

  def []=( pid, path )
    while self.size >= @max
      pid = Process.wait
      self.remove( pid )
    end
    super( pid, path )
  end
end

# utilities -----------------

def encfile( indir )
  outdir = indir.gsub( @flacpath, @oggpath )
  ps = IO.popen %Q{oggenc #{@oggargs.join} "#{indir}" -o "#{outdir}"}
  @ps_hash[ps.pid] = outdir
end

def interupt
  puts "\n" + "Shutting down and removing partially encoded files in #{@cwd}"
  @ps_hash.each do |pid, path|
    File.delete( path )
  end
end

def watcher
  ##INCOMPLETE
  ## needs separate interupt signal handling
  notifier = INotify::Notifier.new
  notifier.watch( @flacpath, :create ) do |e|
    puts e.name + " was modified, rescaning..."
    oggencdir ; Process.waitall ; watcher
  end

  puts "watching #{@flacpath}"
  notifier.run
end

# run the code -------------

trap "INT" do
 interupt
end

if __FILE__ == $0
  parseargs ; oggencdir ; Process.waitall
  watcher if options[:watch]
end

## TODO
# 1. finish SizedPsHash
# 2. test interupt
# - make -o option accept an array
# - a progress bar would be nice (not to mention control over IO)
# - any chance of changing all dirs in oggpath from containing /\flac/i to /ogg/i ?
