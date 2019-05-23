require 'minitest/autorun'
require_relative 'testit'

class TestItTest < Minitest::Test
  def test_path
    assert_equal 'variable.yml', TestIt.new(['--dry-run', 'variable.yml', '--console']).path
  end
end
