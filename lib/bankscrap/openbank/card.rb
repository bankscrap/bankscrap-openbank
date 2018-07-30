require_relative 'utils.rb'

module Bankscrap
  module Openbank
    class Card < ::Bankscrap::Card
      include Utils

      attr_accessor :contract_id

      CARD_ENDPOINT = '/my-money/tarjetas/movimientosCategoria'.freeze

      # Fetch transactions for the given account.
      # By default it fetches transactions for the last month,
      #
      # Returns an array of BankScrap::Transaction objects
      def fetch_transactions_for(connection, start_date: Date.today - 1.month, end_date: Date.today)
        transactions = []
        fields = { producto: contract_id,
                   numeroContrato: id,
                   pan: pan,
                   fechaDesde: format_date(start_date),
                   fechaHasta: format_date(end_date)
                 }
        # Loop over pagination
        until fields.empty?
          data = connection.get(CARD_ENDPOINT, fields: fields)
          transactions += data['lista']['movimientos'].map { |data| build_transaction(data) }.compact
          fields = next_page_fields(data)
        end

        transactions
      end

      def fetch_transactions(start_date: Date.today - 2.years, end_date: Date.today)
        fetch_transactions_for(bank, start_date: start_date, end_date: end_date)
      end

      # Build a transaction object from API data
      def build_transaction(data)
        return if data['estadoPeticion'] == 'L'
        Transaction.new(
          account: self,
          id: data['numeroMovimintoEnDia'],
          amount: money(data['impOperacion']),
          description: data['txtCajero'],
          effective_date: parse_date(data['fechaAnotacionMovimiento']),
          operation_date: parse_date(data['fechaMovimiento']),
          balance: Money.new(0, 'EUR') # TODO: Prepaid/debit cards don't have a Balance - maybe Credit ones do.
        )
      end
    end
  end
end
