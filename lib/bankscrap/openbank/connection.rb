require 'open-uri'
require 'nokogiri'
require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Connection < ::Bankscrap::Bank
      include Utils

      BASE_ENDPOINT    = 'https://www.openbank.mobi'
      LOGIN_ENDPOINT   = '/OPBMOV_IPAD_NSeg_ENS/ws/QUIZ_Def_Listener'
      USER_AGENT       = 'Dalvik/1.6.0 (Linux; U; Android 4.4.4; XT1032 Build/KXB21.14-L1.40)'

      attr_accessor :user_data

      def initialize(user: nil, password: nil, log: false, debug: false, extra_args: nil)
        @user = format_user(user)
        @password = password
        @log = log
        @debug = debug

        initialize_connection

        default_headers
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
