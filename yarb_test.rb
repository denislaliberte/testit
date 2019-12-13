# frozen_string_literal: true

require 'pry'
require 'minitest/autorun'
require_relative 'yarb'
require 'fileutils'
require 'timecop'

module Yarb
  class YarbTest < Minitest::Test
    def test_help
      assert_silent { Yarb.new(['--help']).configure.execute }
      assert_match(/--help.*Output this message/, Yarb.new(['--help']).configure.execute)
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

    def test_pre_configure_hook_can_modify_arguments
      Hook.register(:pre_configure) do |data|
        data[:arguments] = data[:arguments].map(&:upcase)
        data
      end
      assert_equal 'QWER', Yarb.new(['--asdf', 'qwer']).configure.data['ASDF']
    ensure
      Hook.clear(:pre_configure)
    end

    def test_help_message
      help_message = %(
            Usage
              synopsis:
                yarb test.yml
      ).squish
      File.write('tmp/test.yml', { 'usage' => help_message }.to_yaml)
      assert_equal help_message, Yarb.new(['tmp/test.yml', '--help']).configure.execute
    end

    def test_source_return_the_file_content_for_debug_purpose
      source = { 'eval' => 'puts "this script output this message"' }.to_yaml
      File.write('tmp/test.yml', source)
      assert_equal source, Yarb.new(['tmp/test.yml', '--source']).configure.execute
    end

    def test_options
      arguments = ['--key', 'value']
      assert_equal 'value', Yarb.new(arguments).configure.opts(:key)
    end

    def test_options_default
      arguments = []
      assert_equal 'default', Yarb.new(arguments).configure.opts(:key, default: 'default')
    end

    def test_config_option
      File.write("#{home}/config.yml", { 'key' => 'config' }.to_yaml)
      arguments = []
      assert_equal 'config', Yarb.new(arguments, workspace: home).configure.opts(:key, default: 'default')
    end

    def test_flag
      arguments = ['--key']
      assert Yarb.new(arguments).configure.flag?(:key)
    end

    def test_flag_absent
      arguments = ['--other']
      refute Yarb.new(arguments).configure.flag?(:key)
    end

    def test_flag_negative
      arguments = ['--no-key']
      File.write("#{home}/config.yml", { 'key' => true }.to_yaml)
      refute Yarb.new(arguments, workspace: home).configure.flag?(:key)
    end

    def test_noop_flag
      source = { 'eval' => 'throw :wrench' }
      File.write('tmp/test.yml', source.to_yaml)
      File.write("#{home}/config.yml", { 'key' => 'config' }.to_yaml)
      expected_return = Yarb::DEFAULT_CONFIG.merge(
        'file' => 'tmp/test.yml', 'eval' => 'throw :wrench', 'noop' => true, 'key' => 'config'
      )
      assert_equal expected_return, Yarb.new(['tmp/test.yml', '--noop'], workspace: home).configure.execute
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

  class HookTest < Minitest::Test
    def test_register_a_hook
      Hook.register(:test) do |data|
        data[:count] += 1
        data
      end

      assert_equal 2, Hook.execute(:test, count: 1).fetch(:count)
    end

    def test_register_two_hook
      Hook.register(:test) do |data|
        data[:count] += 1
        data
      end
      Hook.register(:test) do |data|
        data[:count] *= 2
        data
      end

      assert_equal 4, Hook.execute(:test, count: 1).fetch(:count)
    end

    def test_clear_a_hook
      Hook.register(:test) do |data|
        data[:count] += 1
        data
      end

      Hook.clear(:test)
      assert_equal 1, Hook.execute(:test, count: 1).fetch(:count)
    end

    def teardown
      Hook.clear(:test)
    end
  end

  class LoggerTest < Minitest::Test
    def test_warning
      assert_output(/warning: test/) { Logger.new(level: 'warning').log(:warning, 'test') }
      assert_output(/warning: test/) { Logger.new(level: 'info').log(:warning, 'test') }
    end

    def test_no_console
      assert_silent { Logger.new(level: 'warning', console: false).log(:warning, 'test') }
    end

    def test_silent
      assert_silent { Logger.new(level: 'error').log(:warning, 'test') }
    end

    def test_wrong_level
      assert_raises(ArgumentError) { Logger.new(level: 'asdf') }
    end

    def test_time
      Timecop.freeze(Time.local(2000)) do
        assert_output(/2000.*warning: test/) { Logger.new(level: 'info').log(:warning, 'test') }
      end
    end

    def test_data
      out, _err = capture_io do
        Logger.new(level: 'warning').log(:warning, 'test', my_data: 'test_data')
      end
      data = YAML.load(out) # rubocop:disable Security/YAMLLoad
      assert_equal :warning, data[:level]
      assert_equal 'test', data[:message]
      assert_equal 'test_data', data[:data][:my_data]
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
