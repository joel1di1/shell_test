require 'pty'
require 'shell_test/pty/countdown_timer'

module ShellTest
  module Pty
    class Agent
      class << self
        # Spawns a PTY session and yields an Agent for that session to the
        # block. Run ensures the PTY process is killed upon errors, and but
        # re-raises the error for additional handling.  Lastly, run sets the
        # command status to $? upon completion.
        def run(cmd, attrs={}) # :yields: agent
          PTY.spawn(cmd) do |slave, master, pid|
            begin
              return yield(new(master, slave, attrs))
            rescue
              Process.kill(9, pid)
              raise
            ensure
              Process.wait(pid)
            end
          end
        end
      end

      # The pty master
      attr_reader :master

      # The pty slave
      attr_reader :slave

      # The timer managing timeouts.  The timer ensures that the timeouts used
      # by expect are never negative, or nil to indicate no timeout.  Timeouts
      # are set on the timer using `timer.timeout=` and retrieved via
      # `timer.timeout`.
      attr_accessor :timer

      # The length of each chunk read from slave by expect. A larger partial
      # length may be specified to speed up expect when the regexp is intended
      # to match strings at a point where the slave will run out of data, for
      # example prompts where the pty waits for input.
      #
      # Note that used inappropriately this may result in more data being read
      # from the slave than is necessary to match the regexp.
      attr_accessor :partial_len

      def initialize(master, slave, attrs={})
        @master = master
        @slave  = slave
        @timer  = attrs[:timer] || CountdownTimer.new
        @partial_len = attrs[:partial_len] || 1
      end

      # Reads from the slave until the regexp is matched and returns the
      # resulting string.  If a nil regexp is given then expect reads until
      # the slave eof.
      #
      # A timeout may be given. If the slave doesn't produce the expected
      # string within the timeout then expect raises an UnsatisfiedError. An
      # UnsatisfiedError will be also be raised if the slave eof is reached
      # before the regexp matches.
      def expect(regexp, timeout=nil)
        timer.timeout = timeout

        buffer = ''
        while true
          if !IO.select([slave],nil,nil,timer.timeout)
            raise UnsatisfiedError.new("timeout", buffer)
          end

          if regexp.nil? && slave.eof?
            break
          end

          # Use readpartial instead of read because it will not block if the
          # length is not fully available.
          #
          # Use readpartial+select instead of read_nonblock to avoid polling in
          # a tight loop.
          begin
            buffer << slave.readpartial(partial_len)
          rescue EOFError
            raise UnsatisfiedError.new($!.message, buffer)
          end

          if regexp && buffer =~ regexp
            break
          end
        end
        buffer
      end

      # Read to the end of the slave.  Raises a UnsatisfiedError if the slave eof is
      # not reached within the timeout.
      def read(timeout=nil)
        expect nil, timeout
      end

      # Writes to the master.
      def write(input)
        master.print input
      end

      # Closes the master and slave.
      def close
        unless master.closed?
          master.close
        end
        unless slave.closed?
          slave.close
        end
      end

      class UnsatisfiedError < RuntimeError
        attr_reader :buffer

        def initialize(message, buffer)
          @buffer = buffer
          super message
        end
      end
    end
  end
end