require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Account < ::Bankscrap::Account
      include Utils

      attr_accessor :contract_id

      ACCOUNT_ENDPOINT = '/my-money/cuentas/movimientos'.freeze

      # Fetch transactions for the given account.
      # By default it fetches transactions for the last month,
      #
      # Returns an array of BankScrap::Transaction objects
      def fetch_transactions_for(connection, start_date: Date.today - 1.month, end_date: Date.today)
        transactions = []

        fields = { producto: contract_id,
                   numeroContrato: id,
                   fechaDesde: format_date(start_date),
                   fechaHasta: format_date(end_date),
                   concepto: '000' }
        # Loop over pagination
        until fields.empty?
          data = connection.get(ACCOUNT_ENDPOINT, fields: fields)
          transactions += data['movimientos'].map { |item| build_transaction(item) }
          fields = next_page_fields(data)
        end

        transactions
      end

      # Build a transaction object from API data
      def build_transaction(data)
        Transaction.new(
          account: self,
          id: data['nummov'],
          amount: money(data['importe']),
          description: data['conceptoTabla'],
          effective_date: parse_date(data['fechaValor']),
          operation_date: parse_date(data['fechaOperacion']),
          balance: money(data['saldo'])
        )
      end
    end
  end
end
