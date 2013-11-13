require "logger_pipe/version"

module LoggerPipe
  autoload :Runner, "logger_pipe/runner"

  class << self
    def run(logger, cmd, options = {})
      Runner.new(logger, cmd, options).execute
    end
  end
end
