require "logger_pipe/version"

module LoggerPipe
  autoload :Runner, "logger_pipe/runner"

  SOURCES = [:none, :stdout, :stderr, :both].freeze

  class << self
    # run
    # @param [Logger] logger
    # @param [String] cmd Command to run on shell
    # @param [Hash] options
    # @option options [Integer] :timeout Seconds, default is nil.
    # @option options [true|false] :dry_run If true given, command is not run actually
    # @option options [Symbol] :returns Which output is used as return, one of :none, :stdout, :stderr, :both
    # @option options [Symbol] :logging Which output is written to logger, one of :none, :stdout, :stderr, :both
    def run(logger, cmd, options = {})
      Runner.new(logger, cmd, options).execute
    end
  end
end
