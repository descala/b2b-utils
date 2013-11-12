# peppol.rb

require "md5"
require "uri"
require "open-uri"
require "rexml/document"

class PeppolDestination

  URLPREFIX="B-"
  URLSUFFIX=".iso6523-actorid-upis.sml.peppolcentral.org/iso6523-actorid-upis::"

  def initialize (participant_id, document_id=nil, process_id=nil)
    @participant_id = participant_id
    @document_id = document_id
    @process_id = process_id
    @verbose = false
  end

  attr_accessor :verbose

  def bye(m)
    raise Exception.new(m)
  end
  
  def access_points

    # Construct SMP url
    smp_url = "http://#{URLPREFIX}#{MD5.new(@participant_id.downcase)}#{URLSUFFIX}#{@participant_id}"
    puts "SMP = #{smp_url}" if @verbose

    # Open SMP url and obtain a list of SMRs
    xml = open(smp_url).read rescue bye("Can not find Participant ID '#{@participant_id}'")
    doc = REXML::Document.new(xml)
    xpath = "//ns2:ServiceMetadataReferenceCollection/"
    element = REXML::XPath.first(doc, xpath)
    bye "Can not find ServiceMetadataReferenceCollection in #{smp_url}" if element.nil?

    # Filter SMRs by @document_id
    smr_urls = []
    element.each_element do |el|
      smr_urls << URI.decode(el.attributes["href"]) if @document_id and URI.decode(el.attributes["href"]) =~ /#{@document_id}/i or !@document_id
    end
    bye "Can not find Document ID" if smr_urls.empty?

    # Filter APs by @process_id
    access_points = []
    smr_urls.each do |smr_url|
      puts "SMR = #{smr_url}" if @verbose 
      signed_service_metadata = open(URI.encode(smr_url)).read rescue bye("Can not open URL #{smr_url}")
      xpath = "/ns3:SignedServiceMetadata/ns3:ServiceMetadata/ns3:ServiceInformation/ns3:ProcessList/ns3:Process"
      doc = REXML::Document.new(signed_service_metadata)
      REXML::XPath.each(doc, xpath) do |process|
        proc_id = process.elements['ProcessIdentifier'].text
        if proc_id =~ /#{@process_id}/i or !@process_id
          ap = {}
          ap[:url] = process.elements["ns3:ServiceEndpointList/ns3:Endpoint/ns2:EndpointReference/ns2:Address"].text
          bye "Can not find EndpointReference" if ap[:url].nil?
          ap[:document_id] = smr_url.gsub(/^http.*::urn:/,"urn:")
          ap[:process_id] = proc_id
          access_points << ap
        end
      end
    end
    bye "Can not find Process ID" if access_points.empty?
    return access_points
  end

end
