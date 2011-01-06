# -*- coding: utf-8 -*-

require 'htmlentities'

require_relative 'string'

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
    node.eachNode { |x| mergeAdjacentStrings(x) }
  end

  def fixRootNewlines(root)
    root.content.each do |x|
      if x.class == String && x == "\n" * x.size
        x.replace("\n")
      end
    end
  end

  def fixWhitespace(node)
    node.each do |element|
      if element.class == String
        element.gsub!(/[\.:\)] $/) do |match|
          match[0]
        end
      else
        if ['TD', 'TH'].include?(element.tag)
          content = element.content
          if content != nil && content.size == 1
            content[0].strip!
          end
        else
          fixWhitespace(element)
        end
      end
    end
  end

  def applyHTMLEntities(node)
    node.each do |element|
      if element.class == String
        entities = HTMLEntities.new
        element.replace(entities.encode(element))
      else
        applyHTMLEntities(element)
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
    return output if node.content == nil
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

  def performAdjacentStringCheck(node)
    wasString = false
    node.each do |element|
      if element.class == String
        if wasString
          classes = node.content.map { |x| x.class }
          raise "Discovered adjacent strings: #{classes.inspect}"
        end
        wasString = true
      else
        performAdjacentStringCheck(element)
        wasString = false
      end
    end
  end

  def performStringReplacements(node)
    replacements =
      [
       ['Bit(BitBase, BitOffset)on', 'Bit(BitBase, BitOffset) on'],
       ['registers.1', 'registers. On Intel 64 processors, CPUID clears the high 32 bits of the RAX/RBX/RCX/RDX registers in all modes.'],
      ]
    return if node.content == nil
    node.content.each do |element|
      if element.class == String
        newElement = replaceCommonStrings(element)
        newElement = replaceStrings(newElement, replacements)
        element.replace(newElement)
      else
        performStringReplacements(element)
      end
    end
  end

  def printMarkedStrings(node)
    targets =
      [
       #'On Intel 64 processors, CPUID clears',
       #'Computes the arctangent of the source operand',
       #'the values being multiplied i',
       #'Remainder',
      ]
    return if node.content == nil
    node.content.each do |element|
      if element.class == String
        targets.each do |target|
          if element.match(target)
            puts element.inspect
          end
        end
      else
        printMarkedStrings(element)
      end
    end
  end

  def descriptionMarkupReplacements(instruction, markup)
    replacements =
      [
       [/<p>.*1.+CPUID clears the high 32 bits of.+<\/p>\n/, ''],
       [' </p>', '</p>'],
       [/<sect>.*<\/sect>/m, '', 'CPUID'],
       [/<p>NOTES:<\/p>.+/m, '', ["FADD/FADDP/FIADD", "FMUL/FMULP/FIMUL", "FPATAN"]],
       [/<p>NOTES:<\/p>.+?\n<\/p>\n/m, '', ["FDIV/FDIVP/FIDIV", "FDIVR/FDIVRP/FIDIVR", "FPREM", "FPREM1"]],
       [/<p>NOTES:<\/p>.+?<p>This instruction/m, '<p>This instruction', ["FSUBR/FSUBRP/FISUBR"]],
       [/<p>IA-32 Architecture Compatibility<\/p>.+/m, ''],
       [/<p>FXCH.+?<\/p>/m, lambda { |x| x.gsub('p>', 'pre>').gsub("\n<", '<') }],
       ["<p>Figure 3-3. ADDSUBPD—Packed Double-FP Add/Subtract</p>\n", ''],
       [" See Figure 3-4.</p>\n<p>Figure 3-4. ADDSUBPS—Packed Single-FP Add/Subtract</p>\n<p>3-50 Vol. 2A ADDSUBPS—Packed Single-FP Add/Subtract</p>", '</p>'],
       ['<p>Table 3-6. Decision Table for CLI Results</p>', ''],
       ["\n\n", "\n"],
      ]

    replacements.each do |replacementData|
      target, replacement = replacementData
      if replacementData.size >= 3
        instructionData = replacementData[2]
        next if
          !
        (
         (instructionData.class == String && instructionData == instruction) ||
         instructionData.include?(instruction)
         )
      end
      if replacement.class == String
        markup.gsub!(target, replacement)
      else
        markup.gsub!(target) { |x| replacement.call(x) }
      end
    end
    return markup
  end

  def performTableCheck(printWarnings, instruction, markup)
    index = markup.index('Table')
    if index != nil
      warning(instruction, "References a table at index #{index}") if printWarnings
      @tableCount += 1
    end
  end

  def extractDescription(instruction, content)
    if instruction == 'JMP'
      descriptionPattern = /(<P>Transfers .+?data and limits. <\/P>)/m
    else
      #the second one is for MAXPD, the third one for GETSEC[SEXIT]
      descriptionPattern = /<P>Description <\/P>(.+?)(?:<P>(?:Operation|FPU Flags Affected|Numeric Exceptions) <\/P>|<P>Operation in a Uni-Processor Platform <\/P>|<Table>\n<TR>\n<TH>Operation <\/TH>|<P>Intel C\/C\+\+ Compiler Intrinsic Equivalent For Returning (?:Mask|Index) <\/P>)/m
    end
    printWarnings = !isFullyProcessedInstruction(instruction)
    descriptionMatch = content.match(descriptionPattern)
    return nil if descriptionMatch == nil
    markup = descriptionMatch[1]
    performTableCheck(printWarnings, instruction, markup)
    root = XMLParser.parse(markup)
    descriptionPostProcessing(root)
    fixWhitespace(root)
    containedAFigure = removeImageData(root)
    containedLeakedImageData = removeLeakedImageData(root)
    mergeAdjacentStrings(root)
    fixRootNewlines(root)
    convertLists(root)
    performStringReplacements(root)
    lowerCaseTags(root)
    printMarkedStrings(root)
    applyHTMLEntities(root)
    if containedAFigure
      warning(instruction, 'Detected a figure') if printWarnings
      @imageCount += 1
    end
    if containedLeakedImageData
      warning(instruction, 'Detected leaked image data') if printWarnings
    end
    markup = root.visualise
    descriptionMarkupReplacements(instruction, markup)
    markup = markup.strip
    return markup
  end
end
