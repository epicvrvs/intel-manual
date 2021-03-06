require 'nil/xml'

require_relative 'OpcodeTable'
require_relative 'Description'
require_relative 'Operation'
require_relative 'FlagsAffected'
require_relative 'FPUFlagsAffected'
require_relative 'InstructionExceptionContainer'

class Instruction < Nil::XMLObject
  attr_reader :name, :summary

  def initialize(name, summary, opcodeTable, encodingTable, description, operation, flagsAffected, fpuFlagsAffected, exceptions)
    super()
    @name = name
    @summary = summary
    add(OpcodeTable.new(opcodeTable, encodingTable))
    add(Description.new(description))
    add(Operation.new(operation))
    add(FlagsAffected.new(flagsAffected)) if flagsAffected != nil
    add(FPUFlagsAffected.new(fpuFlagsAffected)) if fpuFlagsAffected != nil
    add(InstructionExceptionContainer.new(exceptions)) if exceptions != []
  end
end
