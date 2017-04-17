require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Account < ::Bankscrap::Account
      include Utils

      attr_accessor :contract_id

      ACCOUNT_ENDPOINT = '/OPB_BAMOBI_WS_ENS/ws/BAMOBI_WS_Def_Listener'

      # Fetch transactions for the given account.
      # By default it fetches transactions for the last month,
      #
      # Returns an array of BankScrap::Transaction objects
      def fetch_transactions_for(connection, start_date: Date.today - 1.month, end_date: Date.today)
        transactions = []
        end_page = false
        repo = nil
        importe_cta = nil

        # Loop over pagination
        until end_page
          document = connection.post(ACCOUNT_ENDPOINT, fields: xml_account(connection, start_date, end_date, repo, importe_cta))

          transactions += document.xpath('//listadoMovimientos/movimiento').map { |data| build_transaction(data) }

          repo = document.at_xpath('//methodResult/repo')
          importe_cta = document.at_xpath('//methodResult/importeCta')
          end_page = !(value_at_xpath(document, '//methodResult/finLista') == 'N')
        end

        transactions
      end

      def xml_account(connection, from_date, to_date, repo, importe_cta)
        is_pagination = repo ? 'S' : 'N'
        xml_from_date = xml_date(from_date)
        xml_to_date = xml_date(to_date)
        <<-account
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"   xmlns:v1="http://www.isban.es/webservices/BAMOBI/Cuentas/F_bamobi_cuentas_lip/internet/BAMOBICTA/v1">
        #{connection.xml_security_header}
        <soapenv:Body>
          <v1:listaMovCuentasFechas_LIP facade="BAMOBICTA">
            <entrada>
        #{connection.xml_datos_cabecera}
              <datosConexion>#{connection.user_data.children.to_s}</datosConexion>
              <contratoID>#{contract_id}</contratoID>
              <fechaDesde>#{xml_from_date}</fechaDesde>
              <fechaHasta>#{xml_to_date}</fechaHasta>
        #{importe_cta}
              <esUnaPaginacion>#{is_pagination}</esUnaPaginacion>
        #{repo}
            </entrada>
          </v1:listaMovCuentasFechas_LIP>
        </soapenv:Body>
      </soapenv:Envelope>
        account
      end

      def xml_date(date)
        "<dia>#{date.day}</dia><mes>#{date.month}</mes><anyo>#{date.year}</anyo>"
      end

      # Build a transaction object from API data
      def build_transaction(data)
        currency = value_at_xpath(data, 'importe/DIVISA')
        balance = money(value_at_xpath(data, 'importeSaldo/IMPORTE'), value_at_xpath(data, 'importeSaldo/DIVISA'))
        Transaction.new(
          account: self,
          id: value_at_xpath(data, 'numeroMovimiento'),
          amount: money(value_at_xpath(data, 'importe/IMPORTE'), currency),
          description: value_at_xpath(data, 'descripcion'),
          effective_date: Date.strptime(value_at_xpath(data, 'fechaValor'), "%Y-%m-%d"),
          # TODO Falta fecha operacion
          balance: balance
        )
      end
    end
  end
end
