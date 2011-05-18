#!/usr/bin/env ruby

# encodes all flacs in flacdir to ogg (recursively) while
# preserving directory structure, and outputing to oggdir.
# takes two dirs, and an optional n arguments to oggenc.


require 'optparse'
require 'find'
#require 'rb-inotify' only when --watch is passed

# Comandline argument parsing function ---- DONE

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

  if options[:oggargs]
    @oggargs = ARGV[2..-1]
  else
    @oggargs = []
  end

  @watchflag = options[:watch]
end

# directory traversal ------ DONE

def oggencdir
  @ps_hash = SizedPsHash(4)
  Find.find( @flacpath ) do |path|
    if FileTest.directory?( path )
      Find.prune if File.basename(path)[0] == ?.
    elsif File.flac?( path )
      encfile( path )
    end
  end
end


# utilities -----------------

class File
  class << self
    def flac?(path)
      self.file?(path) and self.basename(path) =~ /\.flac/
    end
  end
end

class SizedPsHash < Hash
  ## Takes pids as keys and the path to the
  ## files the process is operating on as values.
  ## Waits until size less than @max to add a new process.
  ## Automatically removes completed processes.

  def self.initialize(max)
    @max = max
    super
  end

  def []=
    until self.size < @max # is this the best way to wait?
      self.clean
    end
    super
  end

  def clean
    self.each do |pid, path|
      ##remove completed processes
    end
  end

end


def encfile( input )
  output = input.gsub( @flacpath, @oggpath )
  t = spawn %Q{oggenc #{@oggargs.join} "#{input}" -o "#{output}"} ## is spawn the best way?
  @ps_hash[t] = output
end

def interupt
  ##UNTESTED
  puts "\n" + "Shutting down and removing partially encoded files in #{@cwd}"
  @ps_hash.each do |pid, path|
    begin
      npid, status = Process.wait2( pid )
      #File.delete( path ) if status.exitstatus == 130 ##if it was killed by ^C
    rescue Errno::ECHILD
      File.delete( path ) unless status.exitstatus == 0
    end
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
  watcher if @watchflag
end

## TODO
# 1. finish SizedPsHash
# 2. test interupt
# 3. a progress bar would be nice (not to mention control over IO)
# 4. any chance of changing all dirs in oggpath from containing /\flac/i to /ogg/i ?
