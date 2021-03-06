require 'nil/xml'

require_relative 'InstructionExceptionEntry'

class InstructionExceptionCategory < Nil::XMLObject
  attr_reader :name

  def initialize(category, exceptionData)
    super()
    setName('Category')
    @name = category
    if exceptionData.class == String
      setContent(exceptionData)
    else
      exceptionData.each do |exception, description|
        if description.class != String
          raise "Invalid description: #{description.inspect}\nIn: #{exceptionData.inspect}"
        end
        add(InstructionExceptionEntry.new(exception, description))
      end
    end
  end
end
