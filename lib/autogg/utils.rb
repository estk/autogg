require 'fileutils'
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

    def parent(path)
      n = 0
      result = ""
      path.reverse.each_char do |c|
        n += 1 if c == '/'
        if n == 1
          result << c
        elsif n >= 2
          break
        end
      end
      return result.reverse
    end

    def initialize(location)
      @log = File.new("#{location}autogg.log", "w+")
      @log.puts "This is the log of excluded files for the most recently run autogg \n\n"
    end

    def <<(path)
      @log.puts "#{parent(path)} -- #{File.basename(path)}"
    end

    def close
      @log.close
    end
  end
end
