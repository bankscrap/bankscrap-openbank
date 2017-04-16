module Bankscrap
  module Openbank
    module Utils
      def value_at_xpath(node, xpath, default = '')
        value = node.at_xpath(xpath)
        value ? value.content.strip : default
      end

      def money(data, xpath)
        Money.new(
          value_at_xpath(data, xpath + '/IMPORTE').delete('.'),
          value_at_xpath(data, xpath + '/DIVISA')
        )
      end
    end
  end
end
