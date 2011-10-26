require 'pty'

module ShellTest
  module ShellMethods
    module Utils
      module_function

      # Spawns a PTY session and returns the Process::Status for the session
      # upon completion. The PTY process is killed upon an unhandled error
      # (but the error is re-raised for further handling).
      #
      # Note that $? is set by spawn but is not reliable until 1.9.2 (ish).
      # Prior to that PTY used a cleanup thread that would wait on a spawned
      # process and raise a PTY::ChildExited error in some cases.  As a result
      # manual calls to Process.wait (which would set $?) cause a race
      # condition. Rely on the output of spawn instead.
      def spawn(cmd)
        PTY.spawn(cmd) do |slave, master, pid|
          begin
            yield(master, slave)

            begin
              Process.wait(pid)
            rescue Errno::ECHILD
              # The thread that raises a ChildExited error can finish waiting
              # on the pid and transfer control back to this thread before
              # actually raising the ChildExited error.  Catch the resulting
              # Errno::ECHILD and pass control back to enter the rescue block
              # below.
              Thread.pass
            end

          rescue PTY::ChildExited
            # handle a ChildExited error on 1.8.6 and 1.8.7 as a 'normal' exit
            # route.  1.9.2 does not exit this way.
            return $!.status

          rescue Exception
            # cleanup the pty on error
            Process.kill(9, pid)

            # clearing the slave allows the wait to complete faster
            while IO.select([slave],nil,nil,0.1)
              begin
                break unless slave.read(1)
              rescue Errno::EIO
                # On some linux (ex ubuntu) read can return an eof or fail with
                # an EIO error when a terminal disconnect occurs and an EIO
                # condition occurs - the exact behavior is unspecified but the
                # meaning is the same... no more data is available, so break.
                break
              end
            end

            # any wait can cause a ChildExited error so account for that here
            # - the $? is indeterminate in this case prior to 1.9.2
            Process.wait(pid) rescue PTY::ChildExited

            raise
          end
        end

        $?
      end
    end
  end
end
