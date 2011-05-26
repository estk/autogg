require 'find'
require_relative 'progressbar'

module OggEncode
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
          end
        end
        Process.waitall ; @ps_hash = {}
      end

      def encfile( inpath )
        outpath = getoutpath( inpath )
        @ps_hash.store( nil, outpath ) do
          IO.popen %Q{oggenc #{@oggargs.join(' ')} "#{inpath}" -o "#{outpath}"}
        end
        @pbar.inc
      end

      def getoutpath( inpath )
        outpath = inpath.gsub( @paths.flac, @paths.ogg )
        outpath.gsub!( /\.flac/, '.ogg' )
      end

      def count_flacs
        c = 0
        Find.find( @paths.flac ) {|p| c += 1 if Flac.exists?( p ) }
        c
      end

      def count_oggs
        c = 0
        Find.find( @paths.ogg ) {|p| c += 1 if Ogg.exists?( p ) }
        c
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
        @pbar = ProgressBar.new( "Subdirectory progress", ( count_flacs - count_oggs ) )
        oggencdir ; @pbar.finish
        watcher if options.watch
      end
    end

    trap "INT" do
      interupt
    end
  end
end
