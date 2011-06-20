require 'find'
require_relative 'progressbar'

module OggEncode
  class OggEncoder
    class << self

      def oggencdir
        @pbar = ProgressBar.new( "Progress", ( count_flacs - count_oggs ) )
        Find.find( @paths.flac ) do |path|
          if FileTest.directory?( path )
            Find.prune if File.basename( path )[0] == ?.
          elsif Flac.exists?( path ) and not Ogg.exists?( getoutpath(path) )
            encfile( path )
          end
        end
        Process.waitall ; @ps_hash = {} ; @pbar.finish
      end

      def encfile( inpath )
        outpath = getoutpath( inpath )
        @ps_hash.store( nil, outpath ) do
          ps = IO.popen %Q{oggenc #{@oggargs.join(' ')} "#{inpath}" -o "#{outpath}"}
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

      def encode( options )
        @options = options
        @paths = options.paths
        @oggargs = options.oggargs
        @ps_hash = SizedPsHash.new( options.max_procs )
        oggencdir
      end
    end

    trap "INT" do
      interupt
    end
  end
end
