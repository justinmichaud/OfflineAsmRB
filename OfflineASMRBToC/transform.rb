# Copyright (C) 2011 Apple Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.

require "config"
require "ast"

class AbsoluteAddress
  def cpp(settings)
    %{#{@address})}
  end
end

class AddImmediates
  def cpp(settings)
    %{#{@left.cpp(settings)} + #{@right.cpp(settings)}}
  end
end

class Address
  def cpp(settings)
    %{address(#{@base.cpp(settings)}, #{@offset.cpp(settings)})}
  end
end

class And
  def cpp(settings)
    %{#{@left.cpp(settings)} && #{@right.cpp(settings)}}
  end
end

class AndImmediates
  def cpp(settings)
    %{#{@left.cpp(settings)} & #{@right.cpp(settings)}}
  end
end

class BaseIndex
  def cpp(settings)
    %{BaseIndex(#{@base.cpp(settings)}, #{@index.cpp(settings)}, #{@scale}, #{@displacement})}
  end
end

class BitnotImmediate
  def cpp(settings)
    %{~#{@child.cpp(settings)}}
  end
end

class ConstDecl
  def cpp(settings)
    %{const auto #{@variable.cpp(settings)} = #{@value.cpp(settings)}}
  end
end

class ConstExpr
  def cpp(settings)
    %{#{@value}}
  end
end

class Error
  def cpp(settings)
    %{{ puts("#{@message}"); std::exit(1); }}
  end
end

class FPRegisterID
  def cpp(settings)
    %{#{@name}}
  end
end

class False
  def cpp(settings)
    %{false}
  end
end

class FalseClass
  def cpp(settings)
    %{False}
  end
end

class IfThenElse
  def cpp(settings, iff = "#if")
    if @elseCase.nil?
      %{
        #{iff} (#{@predicate.cpp(settings)})
            #{@thenCase.cpp(settings)}
        #endif // #{@predicate.cpp(settings)}
      }
    elsif @elseCase.is_a? IfThenElse 
      %{
        #{iff} (#{@predicate.cpp(settings)})
            #{@thenCase.cpp(settings)}
        #{@elseCase.cpp(settings, "#elif")}
      }
    else
      %{
        #{iff}(#{@predicate.cpp(settings)})
            #{@thenCase.cpp(settings)}
        #else // #{@predicate.cpp(settings)}
            #{@elseCase.cpp(settings)}
        #endif // #{@predicate.cpp(settings)}
      }
    end
  end
end

class Immediate
  def cpp(settings)
    %{#{@value}}
  end
end

class Instruction
  def cpp(settings)
    %{#{@opcode.gsub(/break/, '_break')}(#{@operands.map { |op| op.cpp(settings) }.concat(@annotation ? [@annotation] : []).join(', ')})}
  end
end

class Label
  def cpp(settings)
    %{auto #{name.gsub(/[^a-zA-Z0-9_]/, '_')} = label("#{name}")#{@definedInFile ? '->inFile()' : ''}#{@global ? '->global()' : ''}#{@aligned ? ".aligned(#{@alignTo})" : ''}#{@extern ? '->extern_()' : ''}}
  end
end

class LabelReference
  def cpp(settings)
    %{"#{name}"}
  end
end

class LocalLabel
  def cpp(settings)
    %{label("#{name}")}
  end
end

class LocalLabelReference
  def cpp(settings)
    %{"#{name}"}
  end
end

class Macro
  def cpp(settings)
    (@name.nil? ? "" : %{auto #{@name} = }) +
    %{[&](#{@variables.map { |var| %{auto #{var.cpp(settings)}} }.join(', ')}) -> Code {
          CodeCollectionScope __;
          {
            #{@body.cpp(settings)}
          }
          return __.code();
      }
    }
  end
end

class MacroCall
  def cpp(settings)
    %{#{annotation} #{@name}(#{@operands.map { |var| var.cpp(settings) }.join(', ')})}
  end
end

class MulImmediates
  def cpp(settings)
    %{#{left.cpp(settings)} * #{right.cpp(settings)}}
  end
end

class NegImmediate
  def cpp(settings)
    %{-#{@child.cpp(settings)}}
  end
end

class NoChildren
  def cpp(settings)
    %{}
  end
end

class Node
  def cpp(settings)
    %{#{self.class.name}(#{self.children.map { |child| child.cpp(settings) }.join(", ")})}
  end
end

class Not
  def cpp(settings)
    %{!#{operand.cpp(settings)}}
  end
end

class Or
  def cpp(settings)
    %{#{left.cpp(settings)} || #{right.cpp(settings)}}
  end
end

class OrImmediates
  def cpp(settings)
    %{#{left.cpp(settings)} | #{right.cpp(settings)}}
  end
end

class RegisterID
  def cpp(settings)
    %{#{name}}
  end
end

class Sequence
  def cpp(settings)
      newList = []
      @list.each {
          | item |
          item = item.cpp(settings)
          if item.is_a? Sequence
              newList += item.list
          else
              newList << item
          end
      }
      newList.join(";\n") + ";"
  end
end

class Setting
  def cpp(settings)
    %{#{name}}
  end
end

class Sizeof
  def cpp(settings)
    %{sizeof(#{@struct})}
  end
end

class Skip
  def cpp(settings)
    %{}
  end
end

class SpecialRegister
  def cpp(settings)
    %{#{@name}}
  end
end

class StringLiteral
  def cpp(settings)
    %{"#{@value}"}
  end
end

class StructOffset
  def cpp(settings)
    %{StructOffset(#{@struct}, #{@field})}
  end
end

class SubImmediates
  def cpp(settings)
    %{#{@left.cpp(settings)} - #{@right.cpp(settings)}}
  end
end

class True
  def cpp(settings)
    %{true}
  end
end

class TrueClass
  def cpp(settings)
    %{True}
  end
end

class Variable
  def cpp(settings)
    %{#{@name}}
  end
end

class VecRegisterID
  def cpp(settings)
    %{#{@name}}
  end
end

class XorImmediates
  def cpp(settings)
    %{#{@left.cpp(settings)} ^ #{@right.cpp(settings)}}
  end
end

class Comment
  def cpp(settings)
    if @string.start_with?("#")
      %{//#{@string[1..-1]}}
    else
      %{#{@string}}
    end
  end
end
