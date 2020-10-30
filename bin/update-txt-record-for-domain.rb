#!/usr/bin/env ruby

# TODO: remove this
require "pry-byebug"

require "bundler/setup"
require "aws-sdk-route53"
require "json"

class ZoneTxtRecordUpdater
  attr_reader :route53client

  CLUSTER = "live-1"
  EXT_DNS_PREFIX = "_external_dns"
  TXT_VALUE_BASE = %["heritage=external-dns,external-dns/owner=#{CLUSTER},external-dns/resource=ingress/NAMESPACE/INGRESS_NAME"]

  def initialize(route53client)
    @route53client = route53client
  end

  def update_txt_record_for_domain(params)
    domain = params.fetch(:domain)
    namespace = params.fetch(:namespace)
    ingress_name = params.fetch(:ingress_name)

    zone = find_zone_for_domain(domain)
    txt_record = domain_txt_record(zone, domain)
    new_value = TXT_VALUE_BASE.sub("NAMESPACE", namespace).sub("INGRESS_NAME", ingress_name)
    update_txt_record(zone, txt_record, new_value)
  end

  private

  def find_zone_for_domain(domain)
    parts = domain.split(".")
    while parts.any?
      name = parts.join(".") + "."
      zone = search_zones(name)
      return zone unless zone.nil?
      parts.shift
    end

    raise "\nCould not find hosted_zone for domain: #{domain}"
  end

  def domain_txt_record(zone, domain)
    list = route53client
      .list_resource_record_sets(
        hosted_zone_id: zone.id,
        start_record_name: domain
      ).resource_record_sets
    # list contains up to 100 recordsets, starting with the one whose name matches `domain`
    # We only want the external-dns TXT record

    name = "#{EXT_DNS_PREFIX}.#{domain}."
    txt_record = list.find { |r| r.name == name && r.type == "TXT" }

    raise "\nCould not find #{name} TXT record for domain: #{domain}" if txt_record.nil?

    txt_record
  end

  def update_txt_record(zone, txt_record, new_value)
    change_batch = {
      comment: "Use the default ingress",
      changes: [
        action: "UPSERT",
        resource_record_set: {
          name: txt_record.name,
          type: txt_record.type,
          ttl: 300,
          resource_records: [
            {
              value: new_value
            }
          ]
        }
      ]
    }

    route53client.change_resource_record_sets(
      hosted_zone_id: zone.id,
      change_batch: change_batch
    )
  end

  def search_zones(name)
    zones.find {|z| z.name == name}
  end

  def zones
    @list ||= fetch_hosted_zones
  end

  def fetch_hosted_zones
    data = route53client.list_hosted_zones_by_name
    raise "\n>100 zones exist. Update this code to loop until all zones have been returned" unless data.next_hosted_zone_id.nil?
    data.hosted_zones
  end
end

def check_ingress_host(params)
  domain = params.fetch(:domain)
  namespace = params.fetch(:namespace)
  ingress_name = params.fetch(:ingress_name)

  cmd = %[kubectl --namespace #{namespace} get ingress #{ingress_name} -o json]
  json = `#{cmd}`
  raise "\nCould not find ingress #{ingress_name} in namespace #{namespace}" if json == ""

  hostnames = JSON.parse(json).dig("spec", "rules").map { |r| r.fetch("host") }

  raise "\nIngress #{ingress_name} in namespace #{namespace} does not handle traffic for #{domain}" \
    unless hostnames.include?(domain)
end

############################################################

domain, namespace, ingress_name = ARGV

raise "\nPlease supply 3 command-line parameters: domain, namespace, ingress_name" if ingress_name.nil?

params = {
  domain: domain,
  namespace: namespace,
  ingress_name: ingress_name
}

check_ingress_host(params)

client = Aws::Route53::Client.new(
  region: "eu-west-2",
  profile: ENV["AWS_PROFILE"]
)

ZoneTxtRecordUpdater.new(client).update_txt_record_for_domain(params)
