require 'rack/utils'

module ActionDispatch
  class FileHandler
    def initialize(root, cache_control)
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(root)}/
      @file_server   = ::Rack::File.new(@root, cache_control)
    end

    def match?(path)
      path = path.dup

      full_path = path.empty? ? @root : File.join(@root, clean_path_info(::Rack::Utils.unescape(path)))
      paths = "#{full_path}#{ext}"

      matches = Dir[paths]
      match = matches.detect { |m| File.file?(m) }
      if match
        match.sub!(@compiled_root, '')
        match
      end
    end

    def call(env)
      @file_server.call(env)
    end

    def ext
      @ext ||= begin
        ext = ::ActionController::Base.page_cache_extension
        "{,#{ext},/index#{ext}}"
      end
    end

    private

    PATH_SEPS = Regexp.union(*[::File::SEPARATOR, ::File::ALT_SEPARATOR].compact)

    def clean_path_info(path_info)
      parts = path_info.split PATH_SEPS

      clean = []

      parts.each do |part|
        next if part.empty? || part == '.'
        part == '..' ? clean.pop : clean << part
      end

      clean.unshift '/' if parts.empty? || parts.first.empty?

      ::File.join(*clean)
    end
  end

  class Static
    def initialize(app, path, cache_control=nil)
      @app = app
      @file_handler = FileHandler.new(path, cache_control)
    end

    def call(env)
      case env['REQUEST_METHOD']
      when 'GET', 'HEAD'
        path = env['PATH_INFO'].chomp('/')
        if match = @file_handler.match?(path)
          env["PATH_INFO"] = match
          return @file_handler.call(env)
        end
      end

      @app.call(env)
    end
  end
end
