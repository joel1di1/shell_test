require 'shell_test/shell_methods/timer'

module ShellTest
  module ShellMethods
    # Agent wraps a PTY master-slave pair and provides methods for doing reads
    # and writes. The expect method is inspired by the IO.expect method in the
    # stdlib, but tailored to allow for better timeout control.
    class Agent

      # The pty master
      attr_reader :master

      # The pty slave
      attr_reader :slave

      # The timer managing read timeouts.  The timer ensures that the timeouts
      # used by expect are never negative, or nil to indicate no timeout.
      #
      # If implementing a custom timer, note that timeouts are set on the
      # timer using `timer.timeout=` and retrieved via `timer.timeout`.
      attr_reader :timer

      def initialize(master, slave, attrs={})
        @master = master
        @slave  = slave
        @timer  = attrs[:timer] || Timer.new
      end

      # Reads from the slave until the regexp is matched and returns the
      # resulting string.  If a nil regexp is given then expect reads until
      # the slave eof.
      #
      # A timeout may be given. If the slave doesn't produce the expected
      # string within the timeout then expect raises a ReadError. A ReadError
      # will be also be raised if the slave eof is reached before the regexp
      # matches.
      def expect(regexp, timeout=nil)
        timer.timeout = timeout

        buffer = ''
        while true

          # Use read+select instead of read_nonblock to avoid polling in a
          # tight loop.  Don't bother with readpartial and partial lengths. It
          # is an optimization, especially because the regexp matches each
          # loop, but adds complexity because expect could read past the end
          # of the regexp in some cases and it is unlikely to be necessary in
          # test scenarios (ie this is not mean to be a general solution).
          unless IO.select([slave],nil,nil,timer.timeout)
            msg = "timeout waiting for #{regexp ? regexp.inspect : 'EOF'}"
            raise ReadError.new(msg, buffer)
          end

          begin
            c = slave.read(1)
          rescue Errno::EIO
            # On some linux (ex ubuntu) read can return an eof or fail with
            # an EIO error when a terminal disconnect occurs and an EIO
            # condition occurs - the exact behavior is unspecified but the
            # meaning is the same... no more data is available, so break.
            c = nil
          end

          if c.nil?
            if regexp.nil?
              break
            else
              raise ReadError.new("end of file reached", buffer)
            end
          end

          buffer << c

          if regexp && buffer =~ regexp
            break
          end
        end
        buffer
      end

      # Read to the end of the slave.  Raises a ReadError if the slave eof is
      # not reached within the timeout.
      def read(timeout=nil)
        expect nil, timeout
      end

      # Writes to the master. A timeout may be given. If the master doesn't
      # become available for writing within the timeout then write raises an
      # WriteError.
      def write(input, timeout=nil)
        unless IO.select(nil,[master],nil,timeout)
          raise WriteError.new("timeout waiting for master")
        end
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

      # Raised when Agent writes timeout.
      class WriteError < RuntimeError
      end

      # Raised when Agent reads fail or timeout.
      class ReadError < RuntimeError
        # The buffer containing whatever had been read at the time of error.
        attr_reader :buffer

        def initialize(message, buffer)
          @buffer = buffer
          super message
        end
      end
    end
  end
end
