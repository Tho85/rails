require 'abstract_unit'
require 'fileutils'

module StaticTests
  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile").body
  end

  def test_sets_cache_control
    response = get("/index.html")
    assert_html "/index.html", response
    assert_equal "public, max-age=60", response.headers["Cache-Control"]
  end

  def test_serves_static_index_at_root
    assert_html "/index.html", get("/index.html")
    assert_html "/index.html", get("/index")
    assert_html "/index.html", get("/")
    assert_html "/index.html", get("")
  end

  def test_serves_static_file_in_directory
    assert_html "/foo/bar.html", get("/foo/bar.html")
    assert_html "/foo/bar.html", get("/foo/bar/")
    assert_html "/foo/bar.html", get("/foo/bar")
  end

  def test_serves_static_index_file_in_directory
    assert_html "/foo/index.html", get("/foo/index.html")
    assert_html "/foo/index.html", get("/foo/")
    assert_html "/foo/index.html", get("/foo")
  end

  private

    def assert_html(body, response)
      assert_equal body, response.body
      assert_equal "text/html", response.headers["Content-Type"]
    end

    def get(path)
      Rack::MockRequest.new(@app).request("GET", path)
    end
end

class StaticTest < ActiveSupport::TestCase
  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }
  App = ActionDispatch::Static.new(DummyApp, "#{FIXTURE_LOAD_PATH}/public", "public, max-age=60")
  Root = "#{FIXTURE_LOAD_PATH}/public"

  def setup
    @app = App
    @root = Root
  end

  include StaticTests

  def test_custom_handler_called_when_file_is_not_readable
    filename = 'unreadable.html.erb'
    target = File.join(@root, filename)
    FileUtils.touch target
    File.chmod 0200, target
    assert File.exist? target
    assert !File.readable?(target)
    path = "/#{filename}"
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=> path,
      "PATH_INFO"=> path,
      "REQUEST_URI"=> path,
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  ensure
    File.unlink target
  end

  def test_custom_handler_called_when_file_is_outside_root_backslash
    filename = 'shared.html.erb'
    assert File.exist?(File.join(@root, '..', filename))
    path = "/%5C..%2F#{filename}"
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=> path,
      "PATH_INFO"=> path,
      "REQUEST_URI"=> path,
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  end

  def test_custom_handler_called_when_file_is_outside_root
    filename = 'shared.html.erb'
    assert File.exist?(File.join(@root, '..', filename))
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=>"/..%2F#{filename}",
      "PATH_INFO"=>"/..%2F#{filename}",
      "REQUEST_URI"=>"/..%2F#{filename}",
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  end
end