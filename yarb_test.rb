require 'pry'
require 'minitest/autorun'
require_relative 'ya'
require 'fileutils'


class YarbTest < Minitest::Test
  def setup
    Dir.mkdir(home)
    Dir.mkdir("#{home}/.yarb")
    Dir.mkdir("#{home}/.yarb/lib")
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
    assert_equal({}, instance(['--dry-run']).config)
  end

  def test_default_config_file
    File.write("#{home}/.yarb.yml", {key: 'asdf'}.to_yaml)
    assert_equal({key: 'asdf'}, instance(['--dry-run']).config)
  end

  def test_on_env_config_file
    File.write("#{home}/.yarb.prod.yml", {key: 'prod'}.to_yaml)
    assert_equal({key: 'prod'}, instance(['--dry-run', '--on', 'prod']).config)
  end

  def test_on_env_raise_error_for_unexisting_file
    error = assert_raises do
      instance(['--on', 'nonexisting']).config
    end
    assert_match(/nonexisting.yml don't exist/, error.message)
  end

  def test_yaml_data
    File.write("tmp/test.yrb", {key: '<%= opts(0, default: "asdf") %>'}.to_yaml)
    assert_equal({key: 'asdf'}, instance(['--dry-run', 'tmp/test.yrb']).yaml_data)
  end

  def test_data
    File.write("#{home}/.yarb.prod.yml", {key: 'overriden-by-file', url: 'not-overriden.com'}.to_yaml)
    File.write("tmp/test.yrb", {key: 'overriden'}.to_yaml)
    assert_equal('overriden', instance(['tmp/test.yrb', '--dry-run', '--on', 'prod']).data[:key])
    assert_equal('not-overriden.com', instance(['tmp/test.yrb', '--dry-run', '--on', 'prod']).data[:url])
  end

  def test_eval
    File.write('tmp/test.yrb', {'eval' => 'throw :wrench'}.to_yaml)
    assert_throws :wrench do
      instance(['tmp/test.yrb']).execute
    end
  end

  def test_sub_eval
    File.write('tmp/test.yrb', {'eval' => ['test'], 'test' => { 'eval' => 'throw :wrench'}}.to_yaml)
    assert_throws :wrench do
      instance(['tmp/test.yrb']).execute
    end
  end

  def test_lib
    File.write("#{home}/.yarb/lib/test.rb", "throw :wrench")
    assert_throws :wrench do
      instance.execute
    end
  end

  def test_missing_lib_is_silent
    FileUtils.rm_rf("#{home}/.yarb")
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
    assert_match(/Usage:/, instance([ 'tmp/test.yrb', '--help']).execute)
  end

  def test_manual_command
    assert_match(/Installation/, instance(['--man', 'tmp/test.yrb']).execute)
  end

  private

  def instance(args = [])
    Yarb.new(args, home)
  end

  def home
    "#{Dir.pwd}/tmp"
  end
end
