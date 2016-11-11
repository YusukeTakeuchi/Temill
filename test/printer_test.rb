require 'test_helper'
require 'temill/emitter'

class PrinterTest < Minitest::Test
  P = Temill::Emitters::Printer

  def setup
  end

  def assert_printer_out(str, **options, &block)
    sio = StringIO.new('', 'w')
    p = P.new(sio, **options)
    block.call(p)
    assert_equal(str, sio.string)
  end

  def test_obj_to_s
    p = P.new(inspect: :to_s)
    obj1 = '222555'
    obj2 = [:foo, 'bar', {:x => /\A\s+\z/}, Object.new]
    assert_equal(obj1.to_s, p.obj_to_s(obj1))
    assert_equal(obj2.to_s, p.obj_to_s(obj2))

    p = P.new(inspect: lambda{| v | v.size.to_s })
    assert_equal('6', p.obj_to_s(obj1))
    assert_equal('4', p.obj_to_s(obj2))
  end

  def test_print
    assert_printer_out("# hello\n", inspect: to_s){| p |
      p.print_str('hello')
    }
    assert_printer_out("# foo\n# bar\n", inspect: to_s){| p |
      p.print_str("foo\nbar")
    }
  end

  def test_lineno
    p = P.new(StringIO.new('', 'w'), inspect: :to_s)
    p.print_empty_line
    p.print("a\nb\nc\n")
    p.print_empty_line
    assert_equal(6, p.lineno)
  end
end
