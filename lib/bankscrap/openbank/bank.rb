require 'bankscrap'
require 'securerandom'
require 'byebug'
require_relative 'account.rb'
require_relative 'card.rb'
require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Bank < ::Bankscrap::Bank
      include Utils

      # Define the endpoints for the Bank API here
      BASE_ENDPOINT    = 'https://www.openbank.mobi'
      LOGIN_ENDPOINT   = '/OPBMOV_IPAD_NSeg_ENS/ws/QUIZ_Def_Listener'
      USER_AGENT       = 'Dalvik/1.6.0 (Linux; U; Android 4.4.4; XT1032 Build/KXB21.14-L1.40)'
      PRODUCTS_ENDPOINT = '/OPB_BAMOBI_WS_ENS/ws/BAMOBI_WS_Def_Listener'

      attr_accessor :user_data

      def initialize(credentials = {})
        super do
          default_headers
        end
      end

      # Fetch all the accounts for the given user
      #
      # Should returns an array of Bankscrap::Account objects
      def fetch_accounts
        log 'fetch_accounts'

        document = post(PRODUCTS_ENDPOINT, fields: xml_products)

        document.xpath('//cuentas/cuenta').map { |data| build_account(data) } +
          document.xpath('//tarjetas/tarjeta').map { |data| build_card(data) }
      end

      # Fetch transactions for the given account.
      #
      # Account should be a Bankscrap::Account object
      # Should returns an array of Bankscrap::Account objects
      def fetch_transactions_for(product, start_date: Date.today - 1.month, end_date: Date.today)
        product.fetch_transactions_for(self, start_date: start_date, end_date: end_date)
      end

      def post(method, fields: {})
        response = super(BASE_ENDPOINT + method, fields: fields)
        parse_context(response)
      end

      def default_headers
        add_headers(
          'Content-Type'     => 'text/xml; charset=utf-8',
          'User-Agent'       => USER_AGENT,
          'Host'             => 'www.openbank.mobi',
          'Connection'       => 'Keep-Alive',
          'Accept-Encoding'  => 'gzip'
        )
      end

      def login
        log 'login'
        post(LOGIN_ENDPOINT, fields: xml_login(public_ip))
      end

      def parse_context(xml)
        document = Nokogiri::XML(xml)
        @cookie_credential = value_at_xpath(document, '//cookieCredential', @cookie_credential)
        @token_credential = value_at_xpath(document, '//tokenCredential', @token_credential)
        self.user_data = document.at_xpath('//methodResult/datosUsuario') || user_data
        document
      end

      def xml_security_header
        <<-security
        <soapenv:Header>
          <wsse:Security SOAP-ENV:actor="http://www.isban.es/soap/actor/wssecurityB64" SOAP-ENV:mustUnderstand="1" S12:role="wsssecurity" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:S12="http://www.w3.org/2003/05/soap-envelope" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
            <wsse:BinarySecurityToken xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="SSOToken" ValueType="esquema" EncodingType="hwsse:Base64Binary">#{@token_credential}</wsse:BinarySecurityToken>
          </wsse:Security>
        </soapenv:Header>
        security
      end

      def xml_datos_cabecera
        <<-datos
        <datosCabecera>
          <version>3.0.4</version>
          <terminalID>Android</terminalID>
          <idioma>es-ES</idioma>
        </datosCabecera>
        datos
      end

      private

      def xml_products
        <<-products
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v1="http://www.isban.es/webservices/BAMOBI/Posglobal/F_bamobi_posicionglobal_lip/internet/BAMOBIPGL/v1">
        #{xml_security_header}
        <soapenv:Body>
          <v1:obtenerPosGlobal_LIP facade="BAMOBIPGL">
            <entrada>#{xml_datos_cabecera}</entrada>
          </v1:obtenerPosGlobal_LIP>
        </soapenv:Body>
      </soapenv:Envelope>
        products
      end

      # Build an Account object from API data
      def build_account(data)
        currency = value_at_xpath(data, 'impSaldoActual/DIVISA')
        Account.new(
          bank: self,
          id: value_at_xpath(data, 'comunes/contratoID/NUMERO_DE_CONTRATO'),
          name: value_at_xpath(data, 'comunes/descContrato'),
          available_balance: money(value_at_xpath(data, 'importeDispAut/IMPORTE'), currency),
          balance: money(value_at_xpath(data, 'impSaldoActual/IMPORTE'), currency),
          iban: value_at_xpath(data, 'IBAN').tr(' ', ''),
          description: value_at_xpath(data, 'comunes/alias') || value_at_xpath(data, 'comunes/descContrato'),
          contract_id: data.at_xpath('contratoIDViejo').children.to_s
        )
      end

      # Build an Card object from API data
      def build_card(data)
        currency = value_at_xpath(data, 'impSaldoDispuesto/DIVISA')
        Card.new(
          bank: self,
          id: value_at_xpath(data, 'pan'),
          name: value_at_xpath(data, 'comunes/descContrato'),
          available_balance: money(value_at_xpath(data, 'importeDisponible'), currency),
          balance: money(value_at_xpath(data, 'impSaldoDispuesto'), currency),
          iban: value_at_xpath(data, 'comunes/contratoID'),
          description: [value_at_xpath(data, 'comunes/alias') || value_at_xpath(data, 'comunes/descContrato'), value_at_xpath(data, 'descTipoTarjeta')].join(','),
          contract_id: data.at_xpath('comunes/contratoID').children.to_s
        )
      end

      def public_ip
        log 'getting public ip'
        ip = open("http://api.ipify.org").read
        log "public ip: [#{ip}]"
        ip
      end

      def format_user(user)
        user.upcase
      end

      def xml_login(public_ip)
        <<-login
      <v:Envelope xmlns:v="http://schemas.xmlsoap.org/soap/envelope/"  xmlns:c="http://schemas.xmlsoap.org/soap/encoding/"  xmlns:d="http://www.w3.org/2001/XMLSchema"  xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
        <v:Header />
        <v:Body>
          <n0:authenticateCredential xmlns:n0="http://www.isban.es/webservices/TECHNICAL_FACADES/Security/F_facseg_security/internet/loginServicesNSegWS/v1" facade="loginServicesNSegWS">
            <CB_AuthenticationData i:type=":CB_AuthenticationData">
              <documento i:type=":documento">
                <CODIGO_DOCUM_PERSONA_CORP i:type="d:string">#{@user}</CODIGO_DOCUM_PERSONA_CORP>
                <TIPO_DOCUM_PERSONA_CORP i:type="d:string">N</TIPO_DOCUM_PERSONA_CORP>
              </documento>
              <password i:type="d:string">#{@password}</password>
            </CB_AuthenticationData>
            <userAddress i:type="d:string">#{public_ip}</userAddress>
          </n0:authenticateCredential>
        </v:Body>
      </v:Envelope>
        login
      end
    end
  end
end
