require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Card < Account
      include Utils

      CARD_ENDPOINT = '/OPB_BAMOBI_WS_ENS/ws/BAMOBI_WS_Def_Listener'.freeze

      # Fetch transactions for the given account.
      # By default it fetches transactions for the last month,
      #
      # Returns an array of BankScrap::Transaction objects
      def fetch_transactions_for(connection, start_date: Date.today - 1.month, end_date: Date.today)
        transactions = []
        end_page = false
        repos = nil

        # Loop over pagination
        until end_page
          document = connection.post(CARD_ENDPOINT, fields: xml_card(connection, start_date, end_date, repos))

          transactions += document.xpath('//lista/dato').map { |data| build_transaction(data) }

          repos = document.at_xpath('//methodResult/repos')
          end_page = value_at_xpath(document, '//methodResult/finLista') != 'N'
        end

        transactions
      end

      def xml_card(connection, from_date, to_date, repos)
        is_pagination = repos ? 'S' : 'N'
        xml_from_date = xml_date(from_date)
        xml_to_date = xml_date(to_date)
        <<-card
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"   xmlns:v1="http://www.isban.es/webservices/BAMOBI/Tarjetas/F_bamobi_tarjetas_lip/internet/BAMOBITAJ/v1">
        #{connection.xml_security_header}
        <soapenv:Body>
          <v1:listaMovTarjetasFechas_LIP facade="BAMOBITAJ">
            <entrada>
              <datosConexion>#{connection.user_data.children}</datosConexion>
              #{connection.xml_datos_cabecera}
              <contratoTarjeta>#{contract_id}</contratoTarjeta>
              <numeroTarj>#{id}</numeroTarj>
              <fechaDesde>#{xml_from_date}</fechaDesde>
              <fechaHasta>#{xml_to_date}</fechaHasta>
              <esUnaPaginacion>#{is_pagination}</esUnaPaginacion>
              #{repos}
            </entrada>
          </v1:listaMovTarjetasFechas_LIP>
        </soapenv:Body>
      </soapenv:Envelope>
        card
      end

      def xml_date(date)
        "<dia>#{date.day}</dia><mes>#{date.month}</mes><anyo>#{date.year}</anyo>"
      end

      # Build a transaction object from API data
      def build_transaction(data)
        Transaction.new(
          account: self,
          id: value_at_xpath(data, 'movimDia'),
          amount: money(data, 'importeMovto'),
          description: value_at_xpath(data, 'descMovimiento'),
          effective_date: Date.strptime(value_at_xpath(data, 'fechaAnota'), '%Y-%m-%d'),
          # operation_date: Date.strptime(value_at_xpath(data, 'fechaOpera'), "%Y-%m-%d"),
          balance: Money.new(0, 'EUR') # TODO: Prepaid/debit cards don't have a Balance - maybe Credit ones do.
        )
      end
    end
  end
end
