require 'pry'
require 'minitest/autorun'
require_relative 'yarb'
require 'fileutils'


class YarbTest < Minitest::Test
  def setup
    Dir.mkdir(home)
    Dir.mkdir("#{home}/.yrb")
    Dir.mkdir("#{home}/.yrb/lib")
  end

  def teardown
    FileUtils.rm_rf(home)
  end

  def test_path
    assert_equal 'variable.yrb', instance(['variable.yrb', '--console']).path
  end

  def test_default_args
    assert_equal 'default', instance(['--dry-run']).args(0, default: 'default')
  end

  def test_args
    assert_equal 'test.yrb', instance(['test.yrb', '--dry-run']).args(0, default: 'default')
  end

  def test_default_opts
    assert_equal 'default', instance(['--dry-run']).opts(:key, default: 'default')
  end

  def test_opts
    assert_equal 'create', instance(['--key', 'create']).opts(:key, default: 'default')
  end

  def test_opts_alias
    File.write("#{home}/.yrb/config.yml", {'alias' => {'-k' => '--key'}}.to_yaml)
    assert_equal 'create', instance(['-k', 'create']).opts(:key, default: 'default')
  end

  def test_second_argument
    assert_equal 'update', instance(['--key', 'create', '--key2', 'update']).opts(:key2, default: 'default')
  end

  def test_argument_without_value_return_default
    assert_equal 'default', instance(['--key']).opts(:key, default: 'default')
  end

  def test_multiple_arguments_without_value_return_default
    assert_equal 'default', instance(['--key', '--keys2', 'update']).opts(:key, default: 'default')
  end

  def test_flags_not_present
    refute instance([]).flag?(:flag)
  end

  def test_flags_present
    assert instance(['--flag']).flag?(:flag)
  end

  def test_no_config_file
    assert_equal(Yarb::DEFAULT_CONFIG, instance(['--dry-run']).config)
  end

  def test_default_config_file
    File.write("#{home}/.yrb/config.yml", {key: 'asdf'}.to_yaml)
    assert_equal('asdf', instance(['--dry-run']).config[:key])
    assert_equal(Yarb::DEFAULT_CONFIG['alias'], instance(['--dry-run']).config['alias'])
  end

  def test_yaml_data
    File.write("tmp/test.yrb", {key: '<%= opts(0, default: "asdf") %>'}.to_yaml)
    assert_equal({key: 'asdf'}, instance(['--dry-run', 'tmp/test.yrb']).yaml_data)
  end

  def test_eval
    File.write('tmp/test.yrb', {'eval' => 'throw :wrench'}.to_yaml)
    assert_throws :wrench do
      instance(['tmp/test.yrb']).execute
    end
  end

  def test_lib
    File.write("#{home}/.yrb/lib/test.rb", "throw :wrench")
    assert_throws :wrench do
      instance.execute
    end
  end

  def test_missing_lib_is_silent
    FileUtils.rm_rf("#{home}/.yrb")
    assert_silent do
      instance.execute
    end
  end

  def test_dryrun
    File.write('tmp/test.yrb', {'eval' => 'throw :wrench'}.to_yaml)
    assert_match(/throw :wrench/, instance(['tmp/test.yrb', '--dry-run']).execute)
  end

  def test_execute_without_yrb_return_the_help
    assert_match(/Usage:/, instance([]).execute)
  end

  def test_help_command
    assert_match(/Usage:/, instance(['help']).execute)
  end

  def test_manual_command
    assert_match(/Installation/, instance(['man', 'tmp/test.yrb']).execute)
  end

  def test_command_hook
    Yarb.command(:key) do |_yarb|
      throw :wrench
    end
    assert_throws :wrench do
      instance(['key']).execute
    end
  end

  private

  def instance(args = [])
    Yarb.new(args, home)
  end

  def home
    "#{Dir.pwd}/tmp"
  end
end
