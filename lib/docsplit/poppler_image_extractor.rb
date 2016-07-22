module Docsplit

  class PopplerImageExtractor < ImageExtractor
    include Timeoutable

    DEFAULT_TIMEOUT = 120 # seconds
    POPPLER_FORMATS = %w(png jpeg tiff ps eps svg).freeze

    def convert(pdf, size, format, previous = nil)
      each_command(pdf, size, format) do |command, directory, out_file_pattern|
        run_with_timeout(command, @timeout) do
          file_glob = File.join(directory, out_file_pattern)

          Dir[file_glob].each do |temp_file|
            File.delete(temp_file) if File.file?(temp_file)
          end
        end
      end
    end

    private

    def each_command(pdf_path, size, format)
      return enum_for(__method__, pdf_path, size, format) unless block_given?

      each_page_range do |start, finish|
        page_range   = start .. finish
        command_data = build_command(pdf_path, size, format, page_range)
        yield(*command_data)
      end
    end

    def build_command(pdf_path, size, format, page_range = nil)
      tokens = [executable]

      format_switch = poppler_format(format)
      unless POPPLER_FORMATS.include?(format_switch)
        raise ArgumentError, "#{format} is not a supported Poppler format"
      end
      tokens << "-#{ format_switch }"

      if self.density.present?
        tokens << '-r' << self.density
      end

      if page_range.present? && page_range.last > 0
        tokens << '-f' << page_range.first
        tokens << '-l' << page_range.last
      end

      directory    = ensure_directory_for(size)
      pdf_path     = File.expand_path(pdf_path)
      pdf_base     = File.basename(pdf_path, '.*')
      out_prefix   = File.join(directory, pdf_base)
      file_pattern = "#{ pdf_base }-*.#{ format }"

      tokens << pdf_path << out_prefix

      command = tokens.shelljoin

      [command, directory, file_pattern]
    end

    def executable
      "pdftocairo"
    end

    def extract_options(options)
      super
      @timeout = options.fetch(:timeout, DEFAULT_TIMEOUT)
    end

    def poppler_format(format_string)
      format_string  = format_string.to_s

      case format_string
      when 'jpg' then 'jpeg'
      when 'tif' then 'tiff'
      else format_string
      end
    end
  end

end
