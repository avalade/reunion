module Reunion
  class ParserBase

    def parse(text)
    end

    def parse_and_normalize(text, schema)
      results = parse(text)
      transactions = results[:transactions] || []
      statements = results[:statements] || []

      #separate combined results, if provided
      combined = results[:combined]
      if combined
        transactions.concat combined.select { |r| !r[:amount].to_s.strip.empty? }
        statements.concat combined.select { |r| r[:amount].to_s.strip.empty? && !r[:balance].to_s.strip.empty? }
      end 

      #Normalize transactions with the provided schema
      transactions.each do |t|
        t[:schema] = schema
        schema.normalize(t)
      end 

      #Separate unusable data (failed validation of critical fields)
      invalid_transactions = transactions.select{|t| schema.is_broken?(t)}
      transactions -= invalid_transactions
      results[:invalid_transactions] = invalid_transactions

      #Reverse transactions if they're not in ascending order
      if transactions.length > 0 && transactions.first[:date] > transactions.last[:date]
        transactions.reverse!
      end

      #Map hashes to transactions
      results[:transactions] = transactions.map do |t| 
        Transaction.new(schema:schema, from_hash: t)
      end

      #Map hashes to statement objects, and assign the StatementSchema
      statement_schema = StatementSchema.new
      results[:statements] = statements.map do |s|
        s = Statement.new(schema: statement_schema, from_hash: s)
        statement_schema.normalize(s)
        s
      end

      results
    end

    def parse_amount(text)
      return 0 if text.nil? || text.empty?
      BigDecimal.new(text.gsub(/[\$,]/, ""))
    end

    def csv_options
      {headers: :first_row, 
       header_converters:
        ->(h){ h.nil? ? nil : h.encode('UTF-8').downcase.strip.gsub(/\s+/, "_").gsub(/\W+/, "").to_sym}
      }
    end 
  end

  class StrictTsv
    attr_reader :contents
    def initialize(contents)
      @contents = contents
    end
     
    def parse
      headers = contents.lines.first.downcase.strip.split("\t").map{|h|
        h.strip.gsub(/\s+/, "_").gsub(/\W+/, "").to_sym
      }
      contents.lines.to_a[1..-1].map do |line|
        Hash[headers.zip(line.rstrip.split("\t"))]
      end
    end
  end
end