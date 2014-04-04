require 'uri'
require 'json'

module Transit
  class Decoder
    def initialize(options={})
      options = default_options.merge(options)
      @decoders = options[:decoders]
    end

    def default_options
      {decoders: {
          "#{ESC}:" => method(:decode_keyword),
          "#{ESC}b" => method(:decode_byte_array),
          "#{ESC}d" => method(:decode_float),
          "#{ESC}f" => method(:decode_big_decimal),
          "#{ESC}c" => method(:decode_char),
          "#{ESC}$" => method(:decode_transit_symbol),
          "#{ESC}t" => method(:decode_instant),
          "#{ESC}u" => method(:decode_uuid),
          "#{ESC}r" => method(:decode_uri),
          "#{TAG}'"       => method(:decode),
          "#{TAG}t"       => method(:decode_instant),
          "#{TAG}set"     => method(:decode_set),
          "#{TAG}list"    => method(:decode_list),
          "#{TAG}ints"    => method(:decode_ints),
          "#{TAG}longs"   => method(:decode_longs),
          "#{TAG}floats"  => method(:decode_floats),
          "#{TAG}doubles" => method(:decode_doubles),
          "#{TAG}bools"   => method(:decode_bools)
        }}
    end

    def decode(node, cache, as_map_key=false)
      case node
      when String
        decode_string(node, cache, as_map_key)
      when Hash
        decode_hash(node, cache, as_map_key)
      when Array
        node.map {|n| decode(n, cache, as_map_key)}
      else
        node
      end
    end

    def find_encoded_hash_decoder(hash, cache)
      return nil unless hash.size == 1
      key = decode(hash.keys.first, cache, true)
      @decoders[key]
    end

    def decode_hash(hash, cache, as_map_key)
      if decoder = find_encoded_hash_decoder(hash, cache)
        decoder.call(hash.values.first, cache, as_map_key)
      else
        hash.reduce({}) {|h,kv| h.store(decode(kv[0], cache, true), decode(kv[1], cache)); h}
      end
    end

    def decode_string(string, cache, as_map_key)
      if cache.cacheable?(string, as_map_key)
        cache.encode(string, as_map_key)
        parse_string(string, cache, as_map_key)
      elsif cache.cache_key?(string)
        parse_string(cache.decode(string, as_map_key), cache, as_map_key)
      else
        parse_string(string, cache, as_map_key)
      end
    end

    ESCAPED_ESC = Regexp.escape(ESC)
    ESCAPED_SUB = Regexp.escape(SUB)
    IS_ESCAPED  = Regexp.new("^#{ESCAPED_ESC}(#{ESCAPED_SUB}|#{ESCAPED_ESC})")

    def parse_string(str, cache, as_map_key)
      if IS_ESCAPED =~ str
        str[1..-1]
      elsif decoder = @decoders[str[0..1]]
        decoder.call(str[2..-1], cache, as_map_key)
      else
        str
      end
    end

    def decode_uri(s, cache, as_map_key)
      URI(s)
    end

    def decode_keyword(s, cache, as_map_key)
      s.to_sym
    end

    def decode_byte_array(s, cache, as_map_key)
      ByteArray.from_base64(s)
    end

    def decode_float(s, cache, as_map_key)
      Float(s)
    end

    def decode_big_decimal(s, cache, as_map_key)
      BigDecimal.new(s)
    end

    def decode_char(s, cache, as_map_key)
      Char.new(s)
    end

    def decode_transit_symbol(s, cache, as_map_key)
      TransitSymbol.new(s)
    end

    def decode_set(m, cache, as_map_key)
      Set.new(decode(m, cache, as_map_key))
    end

    def decode_list(m, cache, as_map_key)
      TransitList.new(decode(m, cache, as_map_key))
    end

    def decode_instant(m, cache, as_map_key)
      Time.parse(m).utc
    end

    def decode_uuid(s, cache, as_map_key)
      UUID.new(s)
    end

    def decode_typed_array(type, m, cache, as_map_key)
      TypedArray.new(type, decode(m, cache, as_map_key))
    end

    def decode_ints(m, cache, as_map_key)
      decode_typed_array("ints", m, cache, as_map_key)
    end

    def decode_longs(m, cache, as_map_key)
      decode_typed_array("longs", m, cache, as_map_key)
    end

    def decode_floats(m, cache, as_map_key)
      decode_typed_array("floats", m, cache, as_map_key)
    end

    def decode_doubles(m, cache, as_map_key)
      decode_typed_array("doubles", m, cache, as_map_key)
    end

    def decode_bools(m, cache, as_map_key)
      decode_typed_array("bools", m, cache, as_map_key)
    end

    def register(k, &b)
      raise ArgumentError.new(DECODER_ARITY_MESSAGE) unless b.arity == 1
      @decoders[k] = b
    end

    DECODER_ARITY_MESSAGE = <<-MSG
Decoder functions require arity 1
- the string to decode
MSG
  end
end
