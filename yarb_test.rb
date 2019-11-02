require 'pry'
require 'minitest/autorun'
require_relative 'yarb'
require 'fileutils'

class YarbTest < Minitest::Test
  def test_help
    assert_match(/--help.*output this message/, Yarb.new(['--help']).execute)
  end

  def test_example
    assert_match(/manual/, Yarb.new(['example']).execute)
  end

  def test_evaluate_the_example_manual_file_output_the_readme
    File.write('tmp/manual.yml', Yarb.new(['example']).execute)
    assert_equal File.read('README.md'), Yarb.new(['eval', 'tmp/manual.yml']).execute
  end

  def setup
    Dir.mkdir(home)
  end

  def teardown
    FileUtils.rm_rf(home)
  end

  private

  def home
    "#{Dir.pwd}/tmp"
  end
end
