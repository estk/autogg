require_relative 'parser'
require_relative 'utils'
require_relative 'encoder'

module OggEncode
  class Runner
    def self.run(argv)
      options = Parser.parse( argv )
      OggEncoder.encode( options )
    end
  end
end

if $0 == __FILE__
  OggEncode::Runner.run(ARGV)
end
