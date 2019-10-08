require 'pry'
require 'minitest/autorun'
require_relative 'ya'
require 'fileutils'


class YarbTest < Minitest::Test
  def setup
    Dir.mkdir(home)
  end

  def teardown
    FileUtils.rm_rf(home)
  end

  def test_path
    assert_equal 'variable.yml', instance(['--dry-run', 'variable.yml', '--console']).path
  end

  def test_default_args
    assert_equal 'default', instance(['--dry-run']).args(:key, default: 'default')
  end

  def test_args
    assert_equal 'create', instance(['--key', 'create']).args(:key, default: 'default')
  end

  def test_second_argument
    assert_equal 'update', instance(['--key', 'create', '--key2', 'update']).args(:key2, default: 'default')
  end

  def test_argument_without_value_return_default
    assert_equal 'default', instance(['--key']).args(:key, default: 'default')
  end

  def test_multiple_arguments_without_value_return_default
    assert_equal 'default', instance(['--key', '--keys2', 'update']).args(:key, default: 'default')
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
    File.write("#{home}/.yarb.default.yml", {key: 'asdf'}.to_yaml)
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
    File.write("tmp/test.yml", {key: '<%= args(0, default: "asdf") %>'}.to_yaml)
    assert_equal({key: 'asdf'}, instance(['--dry-run', 'tmp/test.yml']).yaml_data)
  end

  def test_data
    File.write("#{home}/.yarb.prod.yml", {key: 'overriden-by-file', url: 'not-overriden.com'}.to_yaml)
    File.write("tmp/test.yml", {key: 'overriden'}.to_yaml)
    assert_equal('overriden', instance(['--dry-run', '--on', 'prod',  'tmp/test.yml']).data[:key])
    assert_equal('not-overriden.com', instance(['--dry-run', '--on', 'prod',  'tmp/test.yml']).data[:url])
  end

  def test_eval
    File.write('tmp/test.yml', {'eval' => 'throw :wrench'}.to_yaml)
    assert_throws :wrench do
      instance(['tmp/test.yml']).execute
    end
  end

  def test_sub_eval
    File.write('tmp/test.yml', {'eval' => ['test'], 'test' => { 'eval' => 'throw :wrench'}}.to_yaml)
    assert_throws :wrench do
      instance(['tmp/test.yml']).execute
    end
  end

  def test_dryrun
    File.write('tmp/test.yml', {'eval' => 'throw :wrench'}.to_yaml)
    assert_match(/throw :wrench/, instance(['tmp/test.yml', '--dry-run']).execute)
  end

  def test_execute_without_yml_return_the_help
    assert_match(/Usage:/, instance([]).execute)
  end

  def test_help_command
    assert_match(/Usage:/, instance(['--help', 'tmp/test.yml']).execute)
  end

  def test_manual_command
    assert_match(/Installation/, instance(['--man', 'tmp/test.yml']).execute)
  end


  private

  def instance(args)
    Yarb.new(args, home)
  end

  def home
    "#{Dir.pwd}/tmp"
  end
end
