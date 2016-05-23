module Bankscrap
  module Openbank
    module Utils
      def value_at_xpath(node, xpath, default = '')
        value = node.at_xpath(xpath)
        value ? value.content.strip : default
      end

      def money(data, currency)
        Money.new(data.gsub('.', ''), currency)
      end
    end
  end
end
