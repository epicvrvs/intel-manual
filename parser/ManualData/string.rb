# -*- coding: utf-8 -*-

class ManualData
  def replaceCommonStrings(input)
    replacements =
      [
       ["\u201C", '"'],
       ["\u201D", '"'],
       ["\uF02B", '+'],
       ["\uF02A", '*'],
       ["\u2019", "'"],
       ["\uF070", 'π'],
       ["\uF0A5", '∞'],
       ["\uF0AC", '='],
       ["\uF02D", '-'],
       ["\u2013", '-'],
       ["\uF03C", '<'],
       ["\uF03E", '>'],
       ["\uF03D", '='],
       ["\uF0DF", '='],
       ["\uF020", ' '], #what is this?!
       ["\uF0B9", '!='],
       ["\uF0B3", '>='],
       ["\uF0A3", '<='],
       ["\u00AB", '<<'],
       ["\u00BB", '>>'],

       ['log210', 'log<sub>2</sub>(10)'],
       ['log102', 'log<sub>10</sub>(2)'],
       ['log2e', 'log<sub>2</sub>(e)'],
       ['loge2', 'log<sub>e</sub>(2)'],

       ["&quot;", '"'],
       ['&lt;', '<'],
       ['&gt;', '>'],
       ['&amp;', '&'],

       ['  ', ' '],
       [" \n", "\n"],
      ]

    return replaceStrings(input, replacements)
  end

  def replaceStrings(element, replacements)
    output = element
    replacements.each do |target, replacement|
      if replacement.class == String
        output = output.gsub(target, replacement)
      else
        output = output.gsub(target) do |match|
          replacement.call(match)
        end
      end
    end
    return output
  end
end
