# -*- coding: utf-8 -*-
require "logger_pipe"

require "timeout"
require 'tempfile'

module LoggerPipe

  class Failure < StandardError
    attr_reader :buffer
    def initialize(msg, buffer)
      super(msg)
      @buffer = buffer
    end
  end

  class Runner
    attr_accessor :logger, :cmd, :timeout
    attr_accessor :returns, :logging

    def initialize(logger, cmd, options = {})
      @logger, @cmd = logger, cmd
      @timeout = options[:timeout]
      @dry_run = options[:dry_run]
      @returns = options[:returns] || :stdout # :nil, :stdout, :stderr, :both
      @logging = options[:logging] || :both # :nil, :stdout, :stderr, :both
    end

    def execute
      if @dry_run
        logger.info("dry run: #{cmd}")
        return nil
      end
      @buf = []
      # systemをタイムアウトさせることはできないので、popenの戻り値を使っています。
      # see http://docs.ruby-lang.org/ja/2.0.0/class/Timeout.html
      @com, @pid = nil, nil
      setup do |actual_cmd, log_enable|
        logger.info("executing: #{actual_cmd}")

        timeout do
          # popenにブロックを渡さないと$?がnilになってしまうので敢えてブロックで処理しています。
          @com = IO.popen(actual_cmd) do |com|
            @com = com
            @pid = com.pid
            while line = com.gets
              @buf << line
              logger.debug(line.chomp) if log_enable
            end
          end
          if $?.exitstatus == 0
            logger.info("\e[32mSUCCESS: %s\e[0m" % [actual_cmd])
            return (returns == :nil) ? nil : @buf.join
          else
            msg = "\e[31mFAILURE: %s\e[0m" % [actual_cmd]
            logger.error(msg)
            raise Failure.new(msg, @buf)
          end
        end

      end
    end

    def timeout(&block)
      begin
        Timeout.timeout(@timeout, &block)
      rescue Timeout::Error => e
        logger.error("[#{e.class.name} #{e.message}] now killing process pid:#{@pid.inspect}: #{cmd}")
        begin
          Process.kill('SIGINT', @pid) if @pid
        rescue Exception => err
          logger.error("[#{err.class.name}] #{err.message}")
        end
        begin
          Timeout.timeout(10) do
            result = @com.read
          end
        rescue Exception => err
          logger.error("failure to get result [#{err.class.name}] #{err.message}")
          result = "<failure to get result>"
        end
        begin
          msg = "\e[31mEXECUTION Timeout: %s\e[0m\n%s\n[result]: %s" % [cmd, @buf.join.strip, result]
          logger.error(msg)
        rescue Exception => err
          logger.error("[#{err.class.name}] #{err.message}")
        end
        raise e
      end
    end

    def setup
      if (returns == :both) && ([:stdout, :stderr].include?(logging))
        raise ArgumentError, "Can' set logging: #{logging.inspect} with returns: #{returns.inspect}"
      elsif (returns == :nil) || (logging == :nil) || (returns == logging)
        actual_cmd =
          case logging
          when :nil    then
            case returns
            when :nil    then "#{cmd} 1>/dev/null 2>/dev/null"
            when :stdout then "#{cmd} 2>/dev/null"
            when :stderr then "#{cmd} 2>&1 1>/dev/null"
            when :both   then "#{cmd} 2>&1"
            end
          when :stdout then "#{cmd} 2>/dev/null"
          when :stderr then "#{cmd} 2>&1 1>/dev/null"
          when :both   then "#{cmd} 2>&1"
          end
        return block_given? ? yield(actual_cmd, logging != :nil) : nil
      else
        Tempfile.open("logger_pipe.stderr.log") do |f|
          f.close
          actual_cmd =
            case returns
            when :stdout then "#{cmd} 2>#{f.path}"
            when :stderr then "#{cmd} 2>&1 1>#{f.path}"
            end
          begin
            return block_given? ? yield(actual_cmd, logging == :both) : nil
          ensure
            logging_subfile(f)
          end
        end
      end
    end

    def logging_subfile(f)
      f.open
      logger.info("--- begin stderr ---\n%s\n--- end stderr ---" % f.read)
    end
  end

end
