module Transit
  ESC = "~"
  SUB = "^"
  RES = "`"
  TAG = "~#"
end

require 'transit/version'
require 'transit/transit_types'
require 'transit/class_hash'
require 'transit/decoder'
require 'transit/rolling_cache'
require 'transit/handler'
require 'transit/writer'
require 'transit/reader'
