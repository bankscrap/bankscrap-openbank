module Bankscrap
  module Openbank
    module Utils

      def money(data)
        Money.new(
          data['importe'] * 100.0,
          data['divisa'].presence || 'EUR'
        )
      end

      def parse_date(date)
        Date.strptime(date, '%Y-%m-%d')
      end

      def format_date(date)
        "%04d-%02d-%02d" % [date.year, date.month, date.day]
      end

      def next_page_fields(data)
        link = data&.fetch('_links', nil)&.fetch('nextPage', nil)&.fetch('href', nil)
        return {} unless link
        uri = URI.parse(link)
        URI::decode_www_form(uri.query).to_h
      end
    end
  end
end
