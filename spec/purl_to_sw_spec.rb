require 'spec_helper'

describe "Purl objects released to SearchWorks" do

  it "SearchWorks has access_facet 'Online' for every Digital Collection object" do
    solr_params = { 'fq' => ['collection_type:"Digital Collection"', '-access_facet:Online'] }
    resp = solr_resp_doc_ids_only(SolrConns.sw, solr_params)
    expect(resp).not_to include("id" => /.+/)  # gets ids of errant records
  end

  it "SearchWorks has building_facet 'Stanford Digital Repoistory' for every Digital Collection object" do
    solr_params = { 'fq' => ['collection_type:"Digital Collection"', '-building_facet:"Stanford Digital Repository"'] }
    resp = solr_resp_doc_ids_only(SolrConns.sw, solr_params)
    expect(resp).not_to include("id" => /.+/)  # gets ids of errant records
  end

  it "number of released Purl digital collections agrees with SW" do
    purl_solr_params = { 'fq' => ['true_releases_ssim:Searchworks', 'identityMetadata_objectType_t:collection'] }
    purl_sw_colls_resp = solr_resp_doc_ids_only(SolrConns.purl, purl_solr_params)
    sw_dig_colls_resp = solr_resp_doc_ids_only(SolrConns.sw, 'fq' => 'collection_type:"Digital Collection"')
    expect(sw_dig_colls_resp.size).to be <= purl_sw_colls_resp.size

    # TODO:  when dispatcher service automagically indexes newly released collections to SW prod, these should match.
    # as of 3/1/2016, dispatcher service has not been deployed, and true_releases_ssim means objects
    # *may* (or may not) have been manually deployed to SW perpetual preview
    # TODO: using pending below causes jenkinsqa build to fail
    skip('when dispatcher service sends true releases to SW prod, these numbers should be equal')
  end

  it "released Purl collection objects are digital collections in SearchWorks" do
    purl_solr_params = { 'fq' => ['true_releases_ssim:Searchworks', 'identityMetadata_objectType_t:collection'],
      'fl' => 'id,catkey_tsi', 'rows' => '300' }
    purl_sw_colls_resp = solr_response(SolrConns.purl, purl_solr_params)
    purl_sw_colls_resp['response']['docs'].each do |purl_solr_doc|
      sw_doc_id =
        if purl_solr_doc['catkey_tsi']
          purl_solr_doc['catkey_tsi']
        else
          bare_druid(purl_solr_doc['id'])
        end
      sw_doc = solr_resp_single_doc(SolrConns.sw, sw_doc_id)['response']['docs'].first
      # TODO: use expect below after dispatcher service automagically tells SW to index newly released colls
      # expect(sw_doc['collection_type']).to eq ['Digital Collection'] if sw_doc
      unless sw_doc && sw_doc['collection_type'] == ['Digital Collection']
        puts "ALERT: expected #{sw_doc_id} to be a Digital Collection!"
      end
    end
    # TODO: using pending below causes jenkinsqa build to fail
    skip('when dispatcher service sends true releases to SW prod, we should use expect statement') # and output ids of probs
  end

  it "Hydrus single items from Purl are single digital repo items without coll in SW" do
    skip "write this test"
  end

  it "all managed Purl objects have a purl link, are online, and no druid" do
    # purl link
    # are online
    # NO druid, just catkey
    skip "write this test"
  end

  it "all Purl objects without ckey have a druid, a purl link and are online" do
    # purl link
    # are online
    # have  druid, no catkey
    skip "write this test"
  end

  it "all true_releases_ssim Purl objects are in SearchWorks" do
    skip "need to write this test -- over 10,000 such ids"
  end

  it "no false_releases_ssim Purl objects are in SearchWorks" do
    skip "need to write this test -- over 10,000 such ids"
  end
end

class SolrConns
  def self.sw
    @@sw_rsolr_conn ||= begin
      baseurl = ENV["SW_URL"]
      if baseurl
        solr_config = { url: baseurl }
      else
        yml_group = ENV["YML_GROUP"] ||= 'test'
        solr_config = YAML.load_file('config/sw_solr.yml')[yml_group]
      end
      solr_conn = RSolr.connect(solr_config)
      puts "SW Solr URL: #{solr_conn.uri}"
      solr_conn
    end
  end

  def self.purl
    @@purl_rsolr_conn ||= begin
      baseurl = ENV["PURL_URL"]
      if baseurl
        solr_config = { url: baseurl }
      else
        yml_group = ENV["YML_GROUP"] ||= 'test'
        solr_config = YAML.load_file('config/purl_solr.yml')[yml_group]
      end
      solr_conn = RSolr.connect(solr_config)
      puts "PURL Solr URL: #{solr_conn.uri}"
      solr_conn
    end
  end
end
