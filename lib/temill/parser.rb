require 'ruby_parser'

class Temill
  ParserResult = Struct.new(:value, :line_range, :sym)

  # Override parser and scanner actions since we need the range of
  # each expr in Ruby programs
  module ParserHack
    def before_reduce(val, *rest)
      #ap val
      val.map{| v |
        if v.kind_of?(ParserResult)
          v.value
        else
          v
        end
      }
    end

    def after_reduce(val, _values, result)
      min = max = nil
      #debug_print_state_stack
      val.each{| v |
        if v.kind_of?(ParserResult) and v.sym != :tNL
          min = [min, v.line_range.min].compact.min
          max = [max, v.line_range.max].compact.max
        end
      }

      if result.kind_of?(Sexp)
        result.line_range = min..max
      end
      # sym is not specified, but OK as long as it is used to check whether
      # the symbol is newline or not.
      ParserResult.new(result, min..max, nil)
    end

    # wrap the value of each token to ParserResult
    def next_token
      sym,val = super
      lineno = lexer.lineno
      [sym, ParserResult.new(val, lineno..lineno, sym)]
    end

    def debug_print_state_stack
      if @racc_tstack
        pp @racc_tstack.zip(@racc_vstack).map{| tok,v |
          [token_to_str(tok), v]
        }
      end
    end
  end

  module RaccHack

    # override all actions and make them call before_reduce/after_reduce
    # before/after each action is executed
    def self.included(klass)
      #racc_action_table,
      #racc_action_check,
      #racc_action_default,
      #racc_action_pointer,
      #racc_goto_table,
      #racc_goto_check,
      #racc_goto_default,
      #racc_goto_pointer,
      #racc_nt_base,
      #racc_reduce_table,
      #racc_token_table,
      #racc_shift_n,
      #racc_reduce_n,
      #racc_use_result_var = klass::Racc_arg

      racc_reduce_table = klass::Racc_arg[9]

      racc_reduce_table.each_slice(3).map{| _,_,method_name |
        method_name
      }.uniq.each{| method_name |
        begin
          method = klass.instance_method(method_name)
        rescue NameError
          next
        end
        method.tap{| original_umethod |
          klass.__send__(:define_method, method_name){| val,_values,result |
            new_val = before_reduce(val, _values, result)
            new_result = original_umethod.bind(self).call(new_val, _values, result)
            after_reduce(val, _values, new_result)
          }
        }
      }
    end

    # should return new val
    def before_reduce(val, _values, result)
      val
    end

    # should return new result
    #
    # Note that val is equal to the object passed to before_reduce,
    # not new val returned by before_reduce
    def after_reduce(val, _values, result)
      result
    end
  end

  module ParserUtils
    module_function

    def add_line_ranges_to_sexp(sexp)
      if sexp.kind_of?(Sexp)
        sexp.each{| elt |
          add_line_ranges_to_sexp(elt)
        }
        sexp << sexp.line_range
      end
      sexp
    end
  end

  # XXX: only Ruby23Parser is supported
  class Ruby23Parser < ::Ruby23Parser
    include RaccHack
    prepend ParserHack
  end
end

class Sexp
  attr_accessor :line_range

  # same as deep_each, but pass self first
  def deep_each_with_self(&block)
    return enum_for(__method__) unless block

    block.call(self)
    deep_each(&block)
  end
end

