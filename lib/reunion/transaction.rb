require 'forwardable'
module Reunion
  class TxnBase
    extend Forwardable

    def initialize
      @data = {}
    end 

    attr_accessor :data
    def_delegators :@data, :size, :[], :[]=, :map, :each, :hash, :eql?, :delete, :key?

    def self.delegated_reader( *arr )
       arr.each do |a|
        self.class_eval do
          define_method(a) do
            @data[a]
          end
        end
       end
     end

    delegated_reader :date, :source 

    def date_str
      date.strftime("%Y-%m-%d")
    end
  end 

  class Statement < TxnBase
    delegated_reader :date, :balance
  end 

  class Transaction < TxnBase

    def initialize(from_hash = nil)
      @data = from_hash.is_a?(Hash) ? from_hash.clone : {}
      @data[:tags] ||= []
    end 
    
    delegated_reader :id, :amount, :description, :tags, :balance_after, :vendor, :client, :account_sym

    delegated_reader :transfer, :transfer_pair, :discard_if_unmerged, :priority

    def tags
      @data[:tags] ||= []
      @data[:tags]
    end 

    def merge_transaction(other)
      new_data = data.merge(other.data) do |key, oldval, newval|
        if key == :tags
          ((oldval || []) + (newval || [])).uniq
        elsif (key == :amount || key == :date) && newval != oldval
          raise "Tried to merge two transactions with dissimilar amounts and dates"
        else
          newval
        end 
      end 
      result = Transaction.new
      result.data = new_data
      result
    end

    def amount_str
      amount.nil? ? "" : ("%.2f" % amount) 
    end 

    def to_long_string
      [id, date_str, amount_str, description] * "    "
    end 

  end
end
