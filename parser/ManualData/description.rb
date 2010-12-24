class ManualData
  def removeNewlinesAroundLink(element, isLeftSideOfLink)
    if element.class != String
      raise "Encountered an unexpected class: #{element.class}"
    end
    return if element.empty?
    target = "\n"
    offset = isLeftSideOfLink ? element.size - 1 : 0
    if isLeftSideOfLink
      offset = -1
      left = 0
      right = -2
    else
      offset = 0
      left = 1
      right = -1
    end
    if element[offset] == target
      element.replace(element[left..right])
    end
  end

  def descriptionPostProcessing(node)
    if node.tag == 'Link'
      if node.content == nil
        raise "Encountered a <Link> tag without any content"
      end
      parentContent = node.parent.content
      offset = parentContent.index(node)
      if offset == nil
        raise "Unable to find a node in its parent's children"
      end
      left = offset - 1
      right = offset + 1
      replacement = parentContent[0..left] + node.content + parentContent[right..-1]
      if offset > 0
        removeNewlinesAroundLink(replacement[left], true)
      end
      if offset < replacement.size - 1
        removeNewlinesAroundLink(replacement[right], false)
      end
      parentContent.replace(replacement)
      return
    end
    return if node.content == nil
    nodes = node.content.reject { |x| x.class == String }
    nodes.each { |x| descriptionPostProcessing(x) }
  end

  def mergeAdjacentStrings(node)
    i = 0
    content = node.content
    return if content == nil
    while i < node.content.size - 1
      currentElement = content[i]
      nextIndex = i + 1
      nextElement = content[nextIndex]
      if currentElement.class == String && nextElement.class == String
        content.delete_at(nextIndex)
        currentElement.replace(currentElement + nextElement)
      else
        i += 1
      end
    end
  end

  def fixRootNewlines(root)
    root.content.each do |x|
      if x.class == String && x == "\n" * x.size
        x.replace("\n")
      end
    end
  end

  def removeTrailingSpaces(node)
    node.each do |element|
      if element.class == String
        if element.matchRight('. ')
          element.replace(element[0..-2])
        end
      else
        removeTrailingSpaces(element)
      end
    end
  end

  def isLeakedImageDataString(input)
    targets = "\u0014\u0018\u001C\u001C\u0014"
    input.each_char do |char|
      if targets.index(char) != nil
        return true
      end
    end
    return false
  end

  def nodeContainsLeakedImageData(node)
    if node.class == String
      return isLeakedImageDataString(node)
    end
    content = node.content
    return false if content == nil
    content.each do |element|
      next if element.class != String
      return true if isLeakedImageDataString(element)
    end
    return false
  end

  #returns if leaked image data was discovered
  def removeLeakedImageData(node)
    content = node.content
    return if content == nil
    i = 0
    output = false
    while i < content.size
      element = content[i]
      if nodeContainsLeakedImageData(element)
        #puts "Deleted node at index #{i}: #{element.inspect}"
        content.delete_at(i)
        output = true
      else
        if element.class != String
          output |= removeLeakedImageData(element)
        end
        i += 1
      end
    end
    return output
  end

  #returns if the tree contained a figure
  def removeImageData(node)
    output = false
    i = 0
    while i < node.content.size
      element = node.content[i]
      if element.class != String
        if element.tag == 'Figure'
          node.content.delete_at(i)
          output = true
          next
        end
        output |= removeImageData(element)
      end
      i += 1
    end
    return output
  end

  def lowerCaseTags(node)
    if node.tag != nil
      node.tag.downcase!
    end
    node.eachNode do |element|
      lowerCaseTags(element)
    end
  end

  def convertLists(node)
    if node.tag == 'L'
      listTag = 'LI'
      newline = "\n"
      replacements = [newline]
      node.eachNode do |list|
        if list.tag != listTag
          error "Discovered an invalid list pattern for tag #{list.tag.inspect}"
        end
        listElements = list.content.reject { |x| !(x.class == XMLNode && x.tag == listTag) }
        if listElements.size != 2
          error "Encountered an unexpected number of <LI> tags in a list (#{listElements.size})"
        end
        replacements += [listElements[1], newline]
      end

      parent = node.parent
      replacementNode = XMLNode.new
      replacementNode.set(parent, 'ul', [])
      replacementNode.content = replacements

      parentContent = parent.content
      index = parentContent.index(node)
      parent.content = parentContent[0, index] + [replacementNode] + parentContent[index + 1..-1]
    else
      node.eachNode do |element|
        convertLists(element)
      end
    end
  end

  def extractDescription(instruction, content)
    if instruction == 'JMP'
      descriptionPattern = /(<P>Transfers .+?data and limits. <\/P>)/m
    else
      #the second one is for MAXPD, the third one for GETSEC[SEXIT]
      descriptionPattern = /<P>Description <\/P>(.+?)(?:<P>(?:Operation|FPU Flags Affected) <\/P>|<Table>|<P>Operation in a Uni-Processor Platform <\/P>)/m
    end
    descriptionMatch = content.match(descriptionPattern)
    return nil if descriptionMatch == nil
    markup = descriptionMatch[1]
    root = XMLParser.parse(markup)
    descriptionPostProcessing(root)
    removeTrailingSpaces(root)
    containedAFigure = removeImageData(root)
    containedLeakedImageData = removeLeakedImageData(root)
    mergeAdjacentStrings(root)
    fixRootNewlines(root)
    convertLists(root)
    lowerCaseTags(root)
    if containedAFigure
      warning(instruction, 'Detected a figure')
    end
    if containedLeakedImageData
      warning(instruction, 'Detected leaked image data')
    end
    return root
  end
end