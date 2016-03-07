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

  it "all true_releases_ssim Purl objects are in SearchWorks" do
    # covered by "all released managed Purl objects ... " and "all released Purl objects without ckey" tests
  end

  it "all released managed Purl objects have expected fields in SW" do
    # want to get all the ids before failing
    missing_sw_docs = []
    missing_managed_purl = []
    missing_access_online = []
    missing_sdr_building = []
    purl_solr_params = { 'fq' => ['true_releases_ssim:Searchworks', 'catkey_tsi:*'],
      'fl' => 'id,catkey_tsi', 'rows' => '20000' }
    purl_resp = solr_response(SolrConns.purl, purl_solr_params)
    purl_resp['response']['docs'].each do |purl_solr_doc|
      sw_solr_doc = solr_resp_single_doc(SolrConns.sw, purl_solr_doc['catkey_tsi'])['response']['docs'].first
      bdruid = bare_druid(purl_solr_doc['id'])
      unless sw_solr_doc
        missing_sw_docs << "#{purl_solr_doc['catkey_tsi']} (for #{bdruid})"
        next
      end
      unless sw_solr_doc['managed_purl_urls'] && sw_solr_doc['managed_purl_urls'].any? { |u| u.match(bdruid) }
        missing_managed_purl << purl_solr_doc['catkey_tsi']
      end
      expect(sw_solr_doc['marcxml'].size).to be > 30
      expect(sw_solr_doc['modsxml']).to be_nil
      expect(sw_solr_doc['druid']).to be_nil
      # FIXME: I believe the following expect statements should be true;
      # uncomment expect lines after new production index installed March 2016
      # expect(sw_solr_doc['access_facet']).to include('Online')
      # expect(sw_solr_doc['building_facet']).to include('Stanford Digital Repository')
      unless sw_solr_doc['access_facet'] && sw_solr_doc['access_facet'].include?('Online')
        missing_access_online << purl_solr_doc['catkey_tsi']
      end
      unless sw_solr_doc['building_facet'] && sw_solr_doc['building_facet'].include?('Stanford Digital Repository')
        missing_sdr_building << purl_solr_doc['catkey_tsi']
      end
    end
    if missing_access_online.empty? || missing_sdr_building.empty? || missing_managed_purl.empty?
      if missing_access_online.empty?
        puts "ALERT: #{missing_access_online.size} managed purl SW docs missing access_facet value of 'Online'"
      end
      if missing_sdr_building.empty?
        puts "ALERT: #{missing_sdr_building.size} managed purl SW docs missing building_facet value of 'Stanford Digital Repository'"
      end
      if missing_managed_purl.empty?
        puts "ALERT: #{missing_managed_purl.size} managed purl SW docs missing expected managed_purl_value"
      end
      # FIXME: uncomment fail after new production index installed March 2016
      # fail "required fields missing (output ids and fields missing)"
    end
    if missing_sw_docs
      puts "ALERT: expected #{missing_sw_docs} to be SW docs (released; ckey in Purl index)"
      fail "expected #{missing_sw_docs} to be SW docs (released; ckey in Purl index)"
    end
  end

  it "all released Purl objects without ckey have docs w expected fields in SW" do
    # want to get all the ids before failing
    missing_sw_docs = []
    missing_access_online = []
    missing_sdr_building = []
    purl_solr_params = { 'fq' => ['true_releases_ssim:Searchworks', '-catkey_tsi:*'],
      'fl' => 'id', 'rows' => '20000' }
    purl_resp = solr_response(SolrConns.purl, purl_solr_params)
    purl_resp['response']['docs'].each do |purl_solr_doc|
      bdruid = bare_druid(purl_solr_doc['id'])
      sw_solr_doc = solr_resp_single_doc(SolrConns.sw, bdruid)['response']['docs'].first
      unless sw_solr_doc
        missing_sw_docs << bdruid
        next
      end
      expect(sw_solr_doc['id']).to eq bdruid
      expect(sw_solr_doc['url_fulltext']).to include(a_string_matching(%r{https?://purl.stanford.edu/#{bdruid}}))
      expect(sw_solr_doc['modsxml'].size).to be > 30
      expect(sw_solr_doc['marcxml']).to be_nil
      expect(sw_solr_doc['druid']).to eq bdruid
      # FIXME: I believe the following expect statements should be true;
      #  uncomment these lines after new production index installed March 2016
      # expect(sw_solr_doc['access_facet']).to include('Online')
      # expect(sw_solr_doc['building_facet']).to include('Stanford Digital Repository')
      unless sw_solr_doc['access_facet'] && sw_solr_doc['access_facet'].include?('Online')
        missing_access_online << bdruid
      end
      unless sw_solr_doc['building_facet'] && sw_solr_doc['building_facet'].include?('Stanford Digital Repository')
        missing_sdr_building << bdruid
      end
    end

    if missing_access_online.empty? || missing_sdr_building.empty?
      if missing_access_online.empty?
        puts "ALERT: #{missing_access_online.size} SW (druid) docs missing access_facet value of 'Online'"
      end
      if missing_sdr_building.empty?
        puts "#{missing_sdr_building.size} SW (druid) docs missing building_facet value of 'Stanford Digital Repository'"
      end
      # FIXME: uncomment fail after new production index installed March 2016
      # fail "required fields missing (output ids and fields missing)"
    end
    if missing_sw_docs
      puts "ALERT: expected #{missing_sw_docs} to be SW docs (released; no ckey in Purl index)"
      fail "expected #{missing_sw_docs} to be SW docs (released; no ckey in Purl index)"
    end
  end

  it "no False Release Purl objects are in SearchWorks" do
    # want to get all the ids before failing
    sw_docs_should_not_exist = []
    sw_docs_w_unexpected_managed_purl = []
    purl_solr_params = { 'fq' => ['false_releases_ssim:Searchworks'], 'fl' => 'id,catkey_tsi', 'rows' => '20000' }
    solr_response(SolrConns.purl, purl_solr_params)['response']['docs'].each do |purl_solr_doc|
      bdruid = bare_druid(purl_solr_doc['id'])
      sw_doc_id =
        if purl_solr_doc['catkey_tsi']
          has_ckey = true
          purl_solr_doc['catkey_tsi']
        else
          bdruid
        end
      sw_doc = solr_resp_single_doc(SolrConns.sw, sw_doc_id)['response']['docs'].first
      if has_ckey && sw_doc
        # one ckey doc may have multiple managed purls
        if sw_doc['managed_purl_urls'] && sw_doc['managed_purl_urls'].any? { |u| u.match(bdruid) }
          sw_docs_w_unexpected_managed_purl << "#{bdruid} for #{sw_doc_id}"
        end
      else
        sw_docs_should_not_exist << bdruid if sw_doc
      end
    end
    if sw_docs_should_not_exist.empty? || sw_docs_w_unexpected_managed_purl.empty?
      if sw_docs_should_not_exist.empty?
        puts "ALERT: Purl false release objects without ckeys exist in SW: #{sw_docs_should_not_exist}"
      end
      if sw_docs_w_unexpected_managed_purl.empty?
        puts "ALERT: Purl false release objects w ckeys have managed purls in SW: #{sw_docs_w_unexpected_managed_purl}"
      end
      fail('unexpected Purl objects in SW')
    end
  end

  def bare_druid(purl_solr_doc_id)
    purl_solr_doc_id.split('druid:').last
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
