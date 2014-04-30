require 'timeout'

module Docsplit
  module Timeoutable

    private

    def run_with_timeout(command, timeout_seconds, options = {}, &timeout_block)
      IO.pipe do |rstdout, wstdout|
        status = nil
        # In case the buffer fills, keep draining it in another thread
        output = ''
        reader_thread = Thread.new do
          output << rstdout.read.to_s until rstdout.eof?
        end

        pid = Process.spawn(command,
                            :in => :close,
                            :out => wstdout,
                            :err => [:child, :out],
                            :pgroup => true)

        begin
          Timeout.timeout(timeout_seconds) do
            _, status = Process.wait2(pid)
          end
        rescue Timeout::Error
          # Negative PID to kill the entire process process group
          Process.kill('KILL', -Process.getpgid(pid))
          # Detach to prevent a zombie process sticking around
          Process.detach(pid)

          timeout_block.call if timeout_block
        ensure
          # Close the write end to signal read end EOF
          wstdout.close
          # Allow read thread to finish the last of the output
          reader_thread.join(5) if reader_thread
        end

        if !status
          raise ExtractionTimedOut,
            "Timed out after #{timeout_seconds} when running `#{command}`:\n#{output}"
        elsif status.exitstatus != 0
          raise ExtractionFailed,
            "Unexpected exit code #{status.exitstatus} when running `#{command}`:\n#{output}"
        end

        return output
      end
    end

  end
end
