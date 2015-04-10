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

    def initialize(logger, cmd, options = {})
      @logger, @cmd = logger, cmd
      @timeout = options[:timeout]
      @dry_run = options[:dry_run]
      @return_from = options[:returns] || :stdout # :nil, :stdout, :stderr, :both
      @logging_from = options[:logging] || :both # :nil, :stdout, :stderr, :both
    end

    def execute
      if @dry_run
        logger.info("dry run: #{cmd}")
        return nil
      end
      logger.info("executing: #{cmd}")
      @buf = []
      # systemをタイムアウトさせることはできないので、popenの戻り値を使っています。
      # see http://docs.ruby-lang.org/ja/2.0.0/class/Timeout.html
      @com, @pid = nil, nil
      stderr_buffer do |stderr_fp|
        timeout do

          # popenにブロックを渡さないと$?がnilになってしまうので敢えてブロックで処理しています。
          @com = IO.popen("#{cmd} 2> #{stderr_fp.path}") do |com|
            @com = com
            @pid = com.pid
            while line = com.gets
              @buf << line
              logger.debug(line.chomp)
            end
          end
          if $?.exitstatus == 0
            logging_stderr(stderr_fp)
            logger.info("\e[32mSUCCESS: %s\e[0m" % [cmd])
            return @buf.join
          else
            logging_stderr(stderr_fp)
            msg = "\e[31mFAILURE: %s\e[0m" % [cmd]
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

    def stderr_buffer
      Tempfile.open("logger_pipe.stderr.log") do |f|
        f.close
        return block_given? ? yield(f) : nil
      end
    end

    def logging_stderr(f)
      f.open
      c = f.read
      if !c.nil? && !c.empty?
        logger.info("--- begin stderr ---\n#{c}\n--- end stderr ---")
      end
    end
  end

end
