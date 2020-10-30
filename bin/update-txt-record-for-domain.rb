#!/usr/bin/env ruby

# TODO: remove this
require "pry-byebug"

require_relative "../lib/ingress_migrator"

def check_ingress_host(params)
  domain = params.fetch(:domain)

  ingress = Ingress.new(
    namespace: params.fetch(:namespace),
    name: params.fetch(:ingress_name)
  )

  raise "\nIngress #{ingress.name} in namespace #{ingress.namespace} does not handle traffic for #{domain}" \
    unless ingress.hostnames.include?(domain)
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
