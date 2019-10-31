require 'pry'
require 'minitest/autorun'
require_relative 'yarb'
require 'fileutils'

class YarbTest < Minitest::Test
  def test_help
    assert_match /--help.*output this message/, Yarb.new(['--help']).execute
  end
end
