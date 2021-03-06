module Elasticsearch
  module Model

    # Provides support for easily and efficiently importing large amounts of
    # records from the including class into the index.
    #
    # @see ClassMethods#import
    #
    module Importing

      # When included in a model, adds the importing methods.
      #
      # @example Import all records from the `Article` model
      #
      #     Article.import
      #
      # @see #import
      #
      def self.included(base)
        base.__send__ :extend, ClassMethods

        adapter = Adapter.from_class(base)
        base.__send__ :include, adapter.importing_mixin
        base.__send__ :extend,  adapter.importing_mixin
      end

      module ClassMethods

        # Import all model records into the index
        #
        # The method will pick up correct strategy based on the `Importing` module
        # defined in the corresponding adapter.
        #
        # @param options [Hash] Options passed to the underlying `__find_in_batches`method
        # @param block  [Proc] Optional block to evaluate for each batch
        #
        # @yield [Hash] Gives the Hash with the Elasticsearch response to the block
        #
        # @return [Fixnum] Number of errors encountered during importing
        #
        # @example Import all records into the index
        #
        #     Article.import
        #
        # @example Set the batch size to 100
        #
        #     Article.import batch_size: 100
        #
        # @example Process the response from Elasticsearch
        #
        #     Article.import do |response|
        #       puts "Got " + response['items'].select { |i| i['index']['error'] }.size.to_s + " errors"
        #     end
        #
        # @example Delete and create the index with appropriate settings and mappings
        #
        #    Article.import force: true
        #
        # @example Refresh the index after importing all batches
        #
        #    Article.import refresh: true
        #
        # @example Import the records into a different index/type than the default one
        #
        #    Article.import index: 'my-new-index', type: 'my-other-type'
        #
        # @example Pass an ActiveRecord scope to limit the imported records
        #
        #    Article.import scope: 'published'
        #
        def import(options={}, &block)
          errors       = 0
          refresh      = options.delete(:refresh) || false
          target_index = options.delete(:index)   || index_name
          target_type  = options.delete(:type)    || document_type

          if options.delete(:force)
            self.create_index! force: true, index: target_index
          end

          __find_in_batches(options) do |batch|
            response = client.bulk \
                         index:   target_index,
                         type:    target_type,
                         body:    batch

            yield response if block_given?

            errors += response['items'].map { |k, v| k.values.first['error'] }.compact.length
          end

          self.refresh_index! if refresh

          return errors
        end

      end

    end

  end
end
