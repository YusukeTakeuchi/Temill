require 'pp'
require 'digest/sha2'
require 'awesome_print'

# most features are implemented in TemillImpl
# @see Temill::TemillImpl
class Temill

  # @param [Hash] opts
  # @option opts [String] :default_indent indent string used when indent guess fails
  #                                       (defaults to '    ')
  # @option opts [Integer] :tabstop the number of spaces a tab counts for.
  #                                 make sense only if both spaces and tabs are used in a line
  #                                 (defaults to 4)
  # @option opts [bool] :compact if true, show only lines that #show methods called are involved
  #                              (defaults to false)
  # @option opts [Symbol,#call] :inspect method to convert obj into String
  #                              (defaults to :pretty_inspect)
  def initialize(**opts)
    _initialize(**opts)
  end

  EVAL_PATH_PREFIX = '(temill eval)/'

  DefaultOptions = {
    tabstop: 4,
    default_indent: '  ',
    compact: false,
    inspect: :pretty_inspect
  }

  # Implementation of Temill:
  # this module will be both included and extended to Temill
  module TemillImpl
    def _initialize(**options)
      @options = DefaultOptions.merge(options)
      reset
    end

    # clear all results added by #show
    def reset
      # absolute_path => SourceFile
      @source_files = {}
      self
    end

    # set options
    # @see Temil#initialize
    def set_options(**options)
      @options.update(options)
      self
    end

    # store values to be shown. You have to use emit to actually output the results.
    # @overload show(val)
    #   @param [Object] val value to show
    # @overload show(*vals)
    #   @param [Array<Object>] vals values to show
    # @overload show(&block)
    #   show the result of block
    # @return [Object] the object shown
    def show(*vals, &block)
      if not vals.empty? and block
        raise ArgumentError, 'either value or block can be specified'
      end

      loc = caller_locations.first
      path = loc.absolute_path

      sf = (@source_files[path] ||= SourceFile.from_path(path, @options))

      if block
        obj = block.call
      else
        case vals.size
        when 0
          obj = nil
        when 1
          obj = vals.first
        else
          obj = vals
        end
      end
      sf.add_result(loc, obj, block_given?)

      obj
    end

    # same as Kernel.eval, but the evaluated code is handled as if
    # it was an independent file.
    # @param [String] src
    # @param [Binding] bind
    # @param [String] fname
    def eval(src, bind=TOPLEVEL_BINDING, fname=default_eval_fname(caller_locations.first))
      path = EVAL_PATH_PREFIX + Digest::SHA256.hexdigest(src) + '/' + fname
      @source_files[path] ||= SourceFile.from_inline_source(src, path, @options)
      Kernel.eval(src, bind, path)
    end

    private def default_eval_fname(loc)
      "#{File.basename(loc.path)}:#{loc.lineno}:#{loc.base_label}"
    end

    # output results to stdout or any IO
    # @param [IO] f IO to output to
    def emit(f=$stdout)
      execute_emitter(Emitters::StdoutEmitter.new(f, @options))
    end

    # output results to files in a directory.
    # a file of original source code corresponds to a output file.
    # @param [String] dir
    def emit_to_directory(dir)
      execute_emitter(Emitters::DirectoryEmitter.new(dir, @options))
    end

    # output results to strings.
    # @return [Hash<String,String>] the keys are filenames and the values are the result for the file
    def emit_to_string
      execute_emitter(Emitters::StringEmitter.new(@options))
    end

    # @param [#call] emitter
    def execute_emitter(emitter=nil, &block)
      if emitter
        emitter.call(@source_files.values, &block)
      elsif block
        block.call(@source_files.values)
      else
        raise ArgumentError, 'no emitter specified'
      end
    end

  end

  class SourceFile
    attr_reader :path, :lines, :sexp
    attr_reader :insertion_points

    def initialize(src, path, options)
      @path = path
      @lines = [nil] + src.lines
      @sexp = Ruby23Parser.new.parse(src, path).value
      @options = options
      @insertion_points = InsertionPointSet.new
    end

    def self.from_inline_source(src, virtual_path, options)
      new(src, virtual_path, options)
    end

    def self.from_path(path, options)
      new(File.read(path), path, options)
    end

    # @param [Thread::Backtrace::Location] caller_loc
    # @param [Object] v value to show
    # @param [bool] with_block whether Temill#show is called with block
    def add_result(caller_loc, v, with_block)
      caller_lineno = caller_loc.lineno
      unless @insertion_points.at_caller_lineno(caller_lineno)
        @insertion_points.add(make_insertion_point(caller_loc, with_block))
      end
      @insertion_points.at_caller_lineno(caller_lineno) << v
      self
    end

    def each_source_line(&block)
      return enum_for(__method__) unless block
      1.upto(@lines.size-1){| i |
        block.call(@lines[i], i)
      }
    end

    private

    # @param [Thread::Backtrace::Location] caller_loc
    def make_insertion_point(caller_loc, with_block=false)
      caller_lineno = caller_loc.lineno
      last_line = caller_lineno
      inner_block_range = nil
      #ParserUtils.add_line_ranges_to_sexp(@sexp) # DEBUG
      @sexp.deep_each_with_self{| v |
        if v.kind_of?(Sexp) and
            [:iter, :call].include?(v.first) and
            v.line_range.min == caller_lineno
          last_line = [last_line, v.line_range.max].max
          if with_block and v.first == :iter and block_sexp = v[3]
            inner_block_range ||= block_sexp.line_range
            if inner_block_range.max < block_sexp.line_range.max
              inner_block_range = v[3].line_range
            end
          end
        end
      }

      # We don't want to use the caller line to guess the indent level
      # of the inner body of the block.
      if inner_block_range
        if inner_block_range.min == caller_lineno
          if inner_block_range.max == caller_lineno
            inner_block_range = nil
          else
            inner_block_range = (caller_lineno+1)..(inner_block_range.max)
          end
        end
      end

      if inner_block_range
        emitter_lineno = inner_block_range.max
        indent = guess_indent_in_block(inner_block_range)
      elsif with_block and
              end_line = @lines[last_line] and
              /\A\s*(?:end|})\s*$/ =~ end_line
        emitter_lineno = last_line - 1
        indent = indent_at(last_line) + @options[:default_indent]
      else
        emitter_lineno = last_line
        indent = indent_at(caller_lineno)
      end

      InsertionPoint.new(caller_loc, emitter_lineno, with_block, indent)
    end

    def indent_at(lineno)
      @lines[lineno][/\A[ \t]*/]
    end

    def guess_indent_in_block(range)
      @lines[range].map{| line |
        line[/\A([ \t]*)\S/] && $1  # remove empty lines
      }.compact.uniq.sort_by{| indent |
        indent.gsub(/\t/, ' ' * @options[:tabstop]).size
      }.first
    end


    # represent a set of insertion points in a single source file
    class InsertionPointSet
      include Enumerable

      def initialize
        @caller_lineno_to_ip = {}
        @emitter_lineno_to_ips = {}
      end

      def add(ip)
        if @caller_lineno_to_ip[ip.caller_lineno]
          false
        else
          @caller_lineno_to_ip[ip.caller_lineno] = ip
          ((@emitter_lineno_to_ips[ip.emitter_lineno] ||= []) << ip).sort_by!{| ips |
            ips.caller_lineno
          }
          true
        end
      end

      # @return [InsertionPoint]
      # @return [nil]
      def at_caller_lineno(lineno)
        @caller_lineno_to_ip[lineno]
      end

      # @return [Array<InsertionPoint>]
      # @return [nil]
      def at_emitter_lineno(lineno)
        @emitter_lineno_to_ips[lineno]
      end

      def each(&block)
        @caller_lineno_to_ip.values.each(&block)
      end
    end

    class InsertionPoint
      attr_reader :caller_loc
      attr_reader :caller_lineno, :emitter_lineno
      attr_reader :indent
      attr_reader :results

      # @param [Thread::Backtrace::Location] caller_loc
      # @param [Integer] emitter_lineno line number after where to emit results
      # @param [bool] with_block whether called with block
      # @param [String] indent
      def initialize(caller_loc, emitter_lineno, with_block, indent)
        @caller_location = caller_loc
        @caller_lineno = caller_loc.lineno
        @emitter_lineno = emitter_lineno
        @with_block = with_block
        @indent = indent
        @results = []
      end

      def <<(result)
        @results << result
      end
    end
  end

  extend TemillImpl
  include TemillImpl

  _initialize
end
