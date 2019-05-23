require 'minitest/autorun'
require_relative 'testit'
require 'fileutils'


class TestItTest < Minitest::Test
  def setup
    Dir.mkdir(home)
  end

  def teardown
    FileUtils.rm_rf(home)
  end

  def test_path
    assert_equal 'variable.yml', instance(['--dry-run', 'variable.yml', '--console']).path
  end

  def test_default_arguments
    assert_equal 'default', instance(['--dry-run']).args(0, default: 'default')
  end

  def test_default_arguments_if_index_out_of_bound
    assert_equal 'default', instance(['--args', 'create,update']).args(2, default: 'default')
  end

  def test_first_argument
    assert_equal 'create', instance(['--args', 'create']).args(0, default: 'default')
  end

  def test_second_argument
    assert_equal 'update', instance(['--args', 'create,update']).args(1, default: 'default')
  end

  def test_no_config_file
    assert_equal({}, instance(['--dry-run']).config)
  end

  def test_default_config_file
    File.write("#{home}/.testit.default.yml", {key: 'asdf'}.to_yaml)
    assert_equal({key: 'asdf'}, instance(['--dry-run']).config)
  end

  def test_on_env_config_file
    File.write("#{home}/.testit.prod.yml", {key: 'prod'}.to_yaml)
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
    File.write("#{home}/.testit.prod.yml", {key: 'overriden-by-file', url: 'not-overriden.com'}.to_yaml)
    File.write("tmp/test.yml", {key: 'overriden'}.to_yaml)
    assert_equal('overriden', instance(['--dry-run', '--on', 'prod',  'tmp/test.yml']).data[:key])
    assert_equal('not-overriden.com', instance(['--dry-run', '--on', 'prod',  'tmp/test.yml']).data[:url])
  end

  private

  def instance(args)
    TestIt.new(args, home)
  end

  def home
    "#{Dir.pwd}/tmp"
  end
end
