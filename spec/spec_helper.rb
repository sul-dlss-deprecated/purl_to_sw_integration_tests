require "yaml"
require 'rsolr'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec-solr'

RSpec.configure do |_config|
end

DOC_IDS_ONLY = { 'fl' => 'id', 'facet' => 'false' }.freeze

# @return [RSpecSolr::SolrResponseHash] Solr response
def solr_resp_single_doc(rsolr_conn, doc_id, solr_params = {})
  solr_response(rsolr_conn, solr_params.merge('qt' => 'document', 'id' => doc_id))
end

# @return [RSpecSolr::SolrResponseHash] Solr response, with no facets, and only the id field for each Solr doc
def solr_resp_ids_from_query(rsolr_conn, query)
  solr_resp_doc_ids_only(rsolr_conn, 'q' => query)
end

# @return [RSpecSolr::SolrResponseHash] Solr response, with no facets, and only the id field for each Solr doc
def solr_resp_doc_ids_only(rsolr_conn, solr_params)
  solr_response(rsolr_conn, solr_params.merge(DOC_IDS_ONLY))
end

private

# send a GET request to the indicated Solr request handler with the indicated Solr parameters
# @return [RSpecSolr::SolrResponseHash] object for rspec-solr testing the Solr response
def solr_response(rsolr_conn, solr_params, req_handler = 'select')
  RSpecSolr::SolrResponseHash.new(
    rsolr_conn.send_and_receive(
      req_handler,
      method: :get,
      params: solr_params.merge("testing" => "sw_index_test")))
end
