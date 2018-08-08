require 'bankscrap'
require 'securerandom'
require 'json'
require 'byebug'
require_relative 'account.rb'
require_relative 'card.rb'
require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Bank < ::Bankscrap::Bank
      include Utils

      # Define the endpoints for the Bank API here
      BASE_ENDPOINT     = 'https://api.openbank.es'.freeze
      LOGIN_ENDPOINT    = '/authenticationcomposite/login'.freeze
      PRODUCTS_ENDPOINT = '/posicion-global-total'.freeze
      USER_AGENT        = 'okhttp/3.9.1'.freeze

      def initialize(credentials = {})
        @token_credential = nil
        super do
          add_headers(
            'Content-Type'     => 'application/json; charset=utf-8',
            'User-Agent'       => USER_AGENT,
            'Connection'       => 'Keep-Alive',
            'Accept-Encoding'  => 'gzip'
          )
        end
      end

      def login
        log 'login'
        login_data = {
            document: @user,
            documentType: "N",
            password: @password,
            force: true,
            osVersion: "8.1.0",
            uuid: "#{SecureRandom.hex(10)[0..2]}-#{SecureRandom.hex(10)[0..6]}",
            mobileDeviceInfo: { pushEnabled:false,
                                rooted: false,
                                version: "1.1.16",
                                device: "SAMSUNG",
                                platform: "ANDROID" }
            }
        post(LOGIN_ENDPOINT, fields: login_data)
      end

      # Fetch all the accounts for the given user
      #
      # Should returns an array of Bankscrap::Account objects
      def fetch_accounts
        log 'fetch_accounts'
        data = get(PRODUCTS_ENDPOINT, fields: { carteras: false,listaSolicitada: 'TODOS',indicadorSaldoPreTarj: false })
        cuentas = data['datosSalidaCuentas']['cuentas'].zip(data['datosSalidaCodIban']['datosIban'])
        cuentas.map{ |data| build_account(data) }
      end

      # Fetch all the cards for the given user
      #
      # Should returns an array of Bankscrap::Card objects
      def fetch_cards
         log 'fetch_cards'
         data = get(PRODUCTS_ENDPOINT, fields: { carteras: false,listaSolicitada: 'TODOS',indicadorSaldoPreTarj: false })
         data['datosSalidaTarjetas']['tarjetas'].map{ |data| build_card(data) }
      end
      # Fetch transactions for the given account.
      #
      # Account should be a Bankscrap::Account object
      # Should returns an array of Bankscrap::Account objects
      def fetch_transactions_for(product, start_date: Date.today - 1.month, end_date: Date.today)
        product.fetch_transactions_for(self, start_date: start_date, end_date: end_date)
      end

      def post(method, fields: {})
        set_auth_headers()
        response = super(BASE_ENDPOINT + method, fields: JSON.generate(fields))
        parse_context(response)
      end

      def get(method, fields: {})
        set_auth_headers()
        response = super(BASE_ENDPOINT + method, params: fields)
        parse_context(response)
      end

      private

      # Build an Account object from API data
      def build_account(data)
        account, iban = data
        Account.new(
          bank: self,
          id: account['cviejo']['numerodecontrato'],
          name: account.fetch('descripcion', '').strip(),
          available_balance: money(account['saldoActual']),
          balance: money(account['saldoActual']),
          iban: iban['codIban'].values().join.strip,
          description: account.fetch('descripcion', '').strip(),
          contract_id: account['cviejo']['subgrupo']
        )
      end

      # Build an Card object from API data
      def build_card(data)
        Card.new(
          bank: self,
          id: data['contrato']['numerodecontrato'],
          name: data['panmdp'],
          avaliable: money(data['saldoDisponible']),
          amount: money(data['saldoDispuesto']),
          pan: data['panmdp'],
          description: data['descripcion'],
          contract_id: data['contrato']['producto'],
          is_credit: data['tipoTarjeta'].to_s == "credit"
        )
      end

      def parse_context(data)
        context = JSON.parse(data)
        @token_credential = context.fetch('tokenCredential', @token_credential)
        context
      end

      def format_user(user)
        user.upcase
      end

      def set_auth_headers
        headers = {}
        headers['openbankauthtoken'] = @token_credential unless @token_credential.nil?
        add_headers(headers) unless headers.empty?
      end
    end
  end
end
