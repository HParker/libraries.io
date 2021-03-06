require 'typhoeus/adapters/faraday'

url = ENV['ELASTICSEARCH_URL'] || 'localhost:9200'

Elasticsearch::Model.client = Elasticsearch::Client.new url: url do |builder|
  builder.use :http_cache, store: Rails.cache, logger: Rails.logger, shared_cache: false, serializer: Marshal
  builder.use FaradayMiddleware::Gzip
  builder.request :retry
  builder.adapter :typhoeus
end
