require 'bankscrap'
require 'securerandom'
require 'byebug'
require_relative 'account.rb'
require_relative 'card.rb'
require_relative 'connection.rb'
require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Bank < ::Bankscrap::Bank
      include Utils

      # Define the endpoints for the Bank API here
      PRODUCTS_ENDPOINT = '/OPB_BAMOBI_WS_ENS/ws/BAMOBI_WS_Def_Listener'

      def initialize(user, password, log: false, debug: false, extra_args: nil)
        @log = log
        # @extra_arg1 = extra_args.with_indifferent_access['extra_arg1']

        @connection = Connection.new(user: user, password: password, log: log,
                                     debug: debug, extra_args: extra_args)
        @connection.login

        super
      end

      # Fetch all the accounts for the given user
      #
      # Should returns an array of Bankscrap::Account objects
      def fetch_accounts
        log 'fetch_accounts'

        document = @connection.post(PRODUCTS_ENDPOINT, fields: xml_products)

        document.xpath('//cuentas/cuenta').map { |data| build_account(data) } +
        document.xpath('//tarjetas/tarjeta').map { |data| build_card(data) }
      end

      # Fetch transactions for the given account.
      #
      # Account should be a Bankscrap::Account object
      # Should returns an array of Bankscrap::Account objects
      def fetch_transactions_for(product, start_date: Date.today - 1.month, end_date: Date.today)
        product.fetch_transactions_for(@connection, start_date: start_date, end_date: end_date)
      end

      private

      def xml_products
        <<-products
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v1="http://www.isban.es/webservices/BAMOBI/Posglobal/F_bamobi_posicionglobal_lip/internet/BAMOBIPGL/v1">
        #{@connection.xml_security_header}
        <soapenv:Body>
          <v1:obtenerPosGlobal_LIP facade="BAMOBIPGL">
            <entrada>#{@connection.xml_datos_cabecera}</entrada>
          </v1:obtenerPosGlobal_LIP>
        </soapenv:Body>
      </soapenv:Envelope>
        products
      end

      # Build an Account object from API data
      def build_account(data)
        Account.new(
          bank: self,
          id: value_at_xpath(data, 'comunes/contratoID/NUMERO_DE_CONTRATO'),
          name: value_at_xpath(data, 'comunes/descContrato'),
          available_balance: value_at_xpath(data, 'importeDispAut/IMPORTE'),
          balance: value_at_xpath(data, 'impSaldoActual/IMPORTE'),
          currency: value_at_xpath(data, 'impSaldoActual/DIVISA'),
          iban: value_at_xpath(data, 'IBAN').tr(' ', ''),
          description: value_at_xpath(data, 'comunes/alias') || value_at_xpath(data, 'comunes/descContrato'),
          contract_id: data.at_xpath('contratoIDViejo').children.to_s
        )
      end

      # Build an Card object from API data
      def build_card(data)
        Card.new(
          bank: self,
          id: value_at_xpath(data, 'pan'),
          name: value_at_xpath(data, 'comunes/descContrato'),
          available_balance: value_at_xpath(data, 'importeDisponible'),
          balance: value_at_xpath(data, 'impSaldoDispuesto'),
          currency: value_at_xpath(data, 'impSaldoDispuesto/DIVISA'),
          iban: value_at_xpath(data, 'comunes/contratoID'),
          description: [value_at_xpath(data, 'comunes/alias') || value_at_xpath(data, 'comunes/descContrato'), value_at_xpath(data, 'descTipoTarjeta')].join(','),
          contract_id: data.at_xpath('comunes/contratoID').children.to_s
        )
      end
    end
  end
end
