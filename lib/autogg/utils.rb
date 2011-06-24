module OggEncode
  
  class Flac < File
    def self.exists?( path )
      file?( path ) and basename( path ) =~ /\.flac$/
    end
  end

  class Ogg < File
    def self.exists?( path )
      file?( path ) and basename( path ) =~ /\.ogg$/
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

  class Logger

    def initialize(location)
      @log = File.new("#{location}autogg.log", "w+")
    end

    def <<(pushed)
      @log.puts "#{pushed[0]} -- #{pushed[1]}"
    end

    def close
      @log.close
    end
  end
end
