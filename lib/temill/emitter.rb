require 'pathname'
require 'fileutils'

class Temill
  module Emitters
    class Base
      def initialize(options)
        @options = options
      end

      # @param [Hash<String, SourceFile>] source_files
      def execute(source_files)
      end

      # @param [Array<SourceFile>] source_files
      def call(source_files)
        execute(source_files)
      end

      def emit_for_source_file(sf, out_f)
        lines_map = [] # map source lineno to output lineno
        compact_ranges = sf.insertion_points.map{| ip | ip.caller_lineno .. ip.emitter_lineno }
        printer = Printer.new(out_f, **@options)
        sf.each_source_line{| line,i |
          lines_map[i] = printer.lineno
          printer.print_raw(line) if not @options[:compact] or compact_ranges.any?{| r | r.cover?(i) }
          if ips = sf.insertion_points.at_emitter_lineno(i)
            ips.each{| ip |
              printer.indent = ip.indent
              printer.print_str(annotation(ip, lines_map[ip.caller_lineno])) if @options[:annotate]
              ip.results.each{| obj |
                printer.print(obj)
              }
            }
          end
        }
      end

      def annotation(ip, output_line_for_caller)
        "temill showing #{ip.results.size} results" +
          " for line #{ip.caller_lineno}" +
          " (line #{output_line_for_caller} in this output)"
      end
    end

    class StdoutEmitter < Base
      def initialize(io, options)
        @io = io
        super(options)
      end

      def execute(source_files)
        source_files.each{| sf |
          puts '#--------------------------------'
          puts "\##{sf.path}"
          puts '#--------------------------------'
          emit_for_source_file(sf, @io)
        }
        nil
      end
    end

    class StringEmitter < Base
      def execute(source_files)
        source_files.map{| sf |
          sio = StringIO.new('', 'w')
          emit_for_source_file(sf, sio)
          [sf.path, sio.string]
        }.to_h
      end
    end

    class DirectoryEmitter < Base
      def initialize(dir_path, options)
        @dir_path = Pathname.new(dir_path)
        super(options)
      end

      def execute(source_files)
        FileUtils.makedirs(@dir_path)
        written = []
        source_files.each{| sf |
          fname = output_fname(sf.path, written)
          File.open(fname, 'w'){| f |
            emit_for_source_file(sf, f)
            written << fname
          }
        }
        nil
      end

      def output_fname(base_fname, written)
        fname_base = (@dir_path + File.basename(base_fname)).to_s
        current_fname = fname_base
        suffix_n = 1
        while written.include?(current_fname)
          current_fname = fname_base + ".#{suffix_n}"
          suffix_n += 1
        end
        current_fname
      end
    end

    class Printer
      attr_reader :output_lines
      attr_accessor :indent

      def initialize(io = $stdout, **options)
        @options = options
        @output_lines = 0
        @indent = ''
        @io = io
      end

      def lineno
        @output_lines + 1
      end

      def obj_to_s(obj)
        case f = @options[:inspect]
        when Symbol
          obj.__send__(f)
        when nil
          obj.pretty_inspect
        else
          f.call(obj)
        end
      end

      def print(obj)
        print_str(obj_to_s(obj))
      end

      def print_str(str)
        str.each_line{| line |
          out @indent
          out '# '
          out_nl line
        }
      end

      def print_empty_line
        out @indent
        out_nl '#'
      end

      def print_raw(str)
        str.each_line{| line |
          out_nl line
        }
      end

      def out(str)
        @io.print(str)
        self
      end

      def out_nl(str=nil)
        @io.puts(str)
        @output_lines += 1
        self
      end
    end

  end
end
