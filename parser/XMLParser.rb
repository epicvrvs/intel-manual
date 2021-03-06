require 'htmlentities'

require_relative 'XMLNode'

class XMLParser
  HTMLEntitiesDecoder = HTMLEntities.new

  def self.parseMarkup(markup, offset = 0)
    output = XMLNode.new
    while offset < markup.size
      tagOffset = markup.index('<', offset)
      break if tagOffset == nil
      if offset != tagOffset
        string = markup[offset..tagOffset - 1]
        output.add(string)
      end
      tagOffset += 1
      endOfTag = markup.index('>', tagOffset)
      tagContent = markup[tagOffset..endOfTag - 1]
      mode, tag, attributes = self.parseTag(tagContent)
      offset = endOfTag + 1
      case mode
      when :open
        node, offset = self.parseMarkup(markup, offset)
        node.set(output, tag, attributes)
        output.add(node)
      when :close
        #regular closing tag
        #can't be bothered to check the tag and such really, that would require a stack check
        #I am basically presuming that the XML input is not totally malformed, which should be the case here
        return output, offset
      when :selfContained
        #tag without content
        node = XMLNode.new
        node.set(output, tag, attributes)
        node.content = nil
        output.add(node)
      else
        error "Invalid mode: #{mode.inspect}"
      end
    end
    if offset != markup.size
      string = markup[offset..-1]
      output.add(string)
    end
    return output, offset
  end

  def self.parse(input)
    output, offset = self.parseMarkup(input)
    return output
  end

  def self.parseTag(content)
    attributes = {}
    mode = :open
    pattern = /^\s*(\/)?\s*([A-Za-z]+)\s*(.*?)(\/)?\s*$/
    innerPattern = /([A-Za-z]+)\s*=\s*"(.*?)"\s*/
    match = content.match(pattern)
    if match == nil
      raise "Unable to parse tag: #{content}"
    end
    isClosing = match[1] != nil
    tag = match[2]
    attributeData = match[3]
    isSelfContained = match[4]
    if isClosing && isSelfContained
      raise "Invalid combination of closing tags: #{content}"
    end
    if isClosing
      mode = :close
    elsif isSelfContained
      mode = :selfContained
    end
    attributeData.scan(innerPattern) do |match|
      name = match[0]
      value = HTMLEntitiesDecoder.decode(match[1])
      attributes[name] = value
    end
    return mode, tag, attributes
  end
end
