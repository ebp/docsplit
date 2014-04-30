require 'timeout'

module Docsplit
  module Timeoutable

    private

    def run_with_timeout(command, timeout_seconds)
      # Ensures rout and wout are closed at end of block
      IO.pipe do |rout, wout|
        pid = Process.spawn(command, :out => wout, :err => wout, :pgroup => true)
        status = nil
        output = nil

        begin
          Timeout.timeout(timeout_seconds) do
            _, status = Process.wait2(pid)

            # Can only read when the process isn't timed out and killed.
            # If the process dies, `rout.readlines` could lock, so it is
            # included inside the timeout.
            wout.close
            output = rout.readlines.join("\n").chomp
            rout.close
          end
        rescue Timeout::Error
          # Negative PID to kill the entire process process group
          Process.kill('KILL', -Process.getpgid(pid))
          # Detach to prevent a zombie process sticking around
          Process.detach(pid)
        end

        if !status || status.exitstatus != 0
          result = "Unexpected exit code #{status.exitstatus} when running `#{command}`:\n#{output}"
          raise ExtractionFailed, result
        end

        return output
      end
    end

  end
end
