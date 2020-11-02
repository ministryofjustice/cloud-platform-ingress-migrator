#!/usr/bin/env ruby

# Script to process a list of ingresses and change route53 TXT records for all
# hostnames listed in each ingress, so that the ingress receives traffic for
# those domains.

# Use this e.g. after upgrading an ingress controller, so that the ingresses on
# the upgraded controller start to handle traffic again.

# TODO: remove this
require "pry-byebug"

require_relative "../lib/ingress_migrator"

def main(list, target_ingress_class)
  delete_ingress_clash_policy
  ztru = ZoneTxtRecordUpdater.new
  list.each { |i| send_traffic_to_ingress(ztru, i, target_ingress_class) }
ensure
  restore_ingress_clash_policy
end

def send_traffic_to_ingress(ztru, i, target_ingress_class)
  ingress = Ingress.new(
    namespace: i.fetch(:namespace),
    name: i.fetch(:ingress)
  )

  params = {
    namespace: ingress.namespace,
    ingress_name: ingress.name
  }

  ingress.hostnames.each do |domain|
    log "  Updating TXT record for #{domain}"
    ztru.update_txt_record_for_domain(params.merge(domain: domain))
  end
end

############################################################

target_ingress_class = "nginx"

ingresses = [
  {
    namespace: "dstest",
    ingress: "helloworld-rubyapp-ingress"
  }
]

main(ingresses, target_ingress_class)
log "Done"
