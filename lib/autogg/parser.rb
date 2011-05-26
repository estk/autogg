require_relative 'optparse'
require_relative 'ostruct'

module OggEncode
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
end
