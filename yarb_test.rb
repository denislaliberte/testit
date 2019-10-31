# frozen_string_literal: true

require 'pry'
require 'minitest/autorun'
require_relative 'yarb'
require 'fileutils'

module Yarb
  class YarbTest < Minitest::Test
    def test_help
      assert_silent { Yarb.new(['--help']).configure.execute }
      assert_match(/--help.*output this message/, Yarb.new(['--help']).configure.execute)
    end

    def test_example
      assert_match(/manual/, Yarb.new(['--example']).configure.execute)
    end

    def test_integration_evaluate_the_example_manual_file_output_the_readme
      File.write('tmp/manual.yml', Yarb.new(['--example']).configure.execute)
      arguments = ['tmp/manual.yml', '--version', '0.3.0', '--install']
      assert_equal File.read('README.md'), Yarb.new(arguments).configure.execute
    end

    def test_integration_config_file
      File.write('tmp/manual.yml', Yarb.new(['--example']).configure.execute)
      File.write("#{home}/config.yml", { 'version' => '0.3.0', 'install' => true }.to_yaml)
      arguments = ['tmp/manual.yml']
      assert_equal File.read('README.md'), Yarb.new(arguments, workspace: home).configure.execute
    end

    def test_integration_function_defined_in_lib_folder
      File.write("#{home}/lib/test.rb", 'def asdf(argument) \'asdf\' + argument end')
      File.write('tmp/test.yml', { 'eval' => "asdf('qwer')" }.to_yaml)
      assert_equal 'asdfqwer', Yarb.new(['tmp/test.yml'], workspace: home).configure.execute
    end

    def test_options
      arguments = ['--key', 'value']
      assert_equal 'value', Yarb.new(arguments).configure.option(:key)
    end

    def test_options_default
      arguments = []
      assert_equal 'default', Yarb.new(arguments).configure.option(:key, default: 'default')
    end

    def test_config_option
      File.write("#{home}/config.yml", { 'key' => 'config' }.to_yaml)
      arguments = []
      assert_equal 'config', Yarb.new(arguments, workspace: home).configure.option(:key, default: 'default')
    end

    def test_flag
      arguments = ['--key']
      assert Yarb.new(arguments).configure.flag?(:key)
    end

    def test_flag_negative
      arguments = ['--other']
      refute Yarb.new(arguments).configure.flag?(:key)
    end

    def test_eval_without_a_file_output_a_warning
      File.write('tmp/manual.yml', {}.to_yaml)
      assert_output(/warning: eval key is missing/) { Yarb.new(['tmp/manual.yml']).configure.execute }
    end

    def test_eval_without_a_file_output_a_warning_if_log_level_is_error
      File.write('tmp/manual.yml', {}.to_yaml)
      assert_silent { Yarb.new(['tmp/manual.yml', '--log-level', 'error']).configure.execute }
    end

    def setup
      Dir.mkdir(home)
      Dir.mkdir("#{home}/lib")
    end

    def teardown
      FileUtils.rm_rf(home)
    end

    private

    def home
      "#{Dir.pwd}/tmp"
    end
  end

  class LoggerTest < Minitest::Test
    def test_warning
      assert_output(/warning: test/) { Logger.new(level: 'warning').log(:warning, 'test') }
      assert_output(/warning: test/) { Logger.new(level: 'info').log(:warning, 'test') }
    end

    def test_silent
      assert_silent { Logger.new(level: 'error').log(:warning, 'test') }
    end

    def test_wrong_level
      assert_raises(ArgumentError) { Logger.new(level: 'asdf') }
    end
  end
end

class HashTest < Minitest::Test
  def test_recursive_merge
    original = { a: 1, b: { c: 2 }, d: 3 }
    expected = { a: 1, b: { c: 4 }, d: 3 }
    assert_equal expected, original.recursive_merge(b: { c: 4 })
  end
end
