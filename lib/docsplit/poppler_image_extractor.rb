module Docsplit

  class PopplerImageExtractor < ImageExtractor
    include Timeoutable

    DEFAULT_TIMEOUT = 120 # seconds
    POPPLER_FORMATS = %w(png jpeg tiff ps eps svg).freeze

    def convert(pdf, size, format, previous=nil)
      poppler_format = case format.to_s
                       when 'jpg' then 'jpeg'
                       when 'tif' then 'tiff'
                       else format.to_s
                       end
      unless POPPLER_FORMATS.include?(poppler_format)
        raise ArgumentError, "#{format} is not a supported Poppler format"
      end

      tempdir   = Dir.mktmpdir
      basename  = File.basename(pdf, File.extname(pdf))
      directory = directory_for(size)
      escaped_pdf = ESCAPE[pdf]
      FileUtils.mkdir_p(directory) unless File.exists?(directory)

      # Output files are: #{out_path}-#{page_number}.#{format}
      out_path = ESCAPE[File.join(directory, basename)]
      cmd = "#{executable} -#{poppler_format} -r #{@density} #{escaped_pdf} #{out_path}"
      run_with_timeout(cmd, @timeout) do
        Dir["#{out_path}-*.#{format}"].each do |tmpfile|
          File.delete(tmpfile)
        end
      end
    ensure
      FileUtils.remove_entry_secure tempdir if tempdir && File.exists?(tempdir)
    end

    private

    def executable
      "pdftocairo"
    end

    def extract_options(options)
      super
      @timeout = options.fetch(:timeout, DEFAULT_TIMEOUT)
    end

  end

end
