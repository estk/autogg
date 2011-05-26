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
