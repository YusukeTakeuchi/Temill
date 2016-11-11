require 'test_helper'

class TemillTest < Minitest::Test
  def setup
    Temill.reset
  end

  def teardown
  end

  def assert_start_with_each_line(pat, str)
    pat.lines.zip(str.lines).each{| pline,sline |
      assert(sline, 'str lines are fewer than pattern lines')

      pline = pline.chomp
      sline = sline.chomp
      assert(sline.start_with?(pline), "'#{pline}' is not a prefix of '#{sline}'")
    }
  end

  def test_that_it_has_a_version_number
    refute_nil ::Temill::VERSION
  end

  def test_show
    Temill.eval(<<-EOS)
      Temill.show(22)
    EOS

    assert_start_with_each_line(<<-EOS,
      Temill.show(22)
      #
      # 22
    EOS
    Temill.emit_to_string.values.first)
  end

  def test_multiline_argument
    Temill.eval(<<-EOS)
      Temill.show(
        55
      )
    EOS

    assert_start_with_each_line(<<-EOS,
      Temill.show(
        55
      )
      #
      # 55
    EOS
    Temill.emit_to_string.values.first)
  end

  def test_set_options
    Temill.set_options(default_indent: ' ' * 8)
    Temill.eval(<<-EOS)
      Temill.show{ 33
      }
    EOS

    assert_start_with_each_line(<<-EOS,
      Temill.show{ 33
              #
              # 33
      }
    EOS
    Temill.emit_to_string.values.first)
  end
end
