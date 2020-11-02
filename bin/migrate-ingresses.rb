#!/usr/bin/env ruby

# Script to migrate multiple ingresses to a different ingress controller, by
# deploying a second ingress on that controller, and updating the route53 TXT
# record for each of the ingress's hostnames

# TODO: remove this
require "pry-byebug"

require_relative "../lib/ingress_migrator"

def main(list, target_ingress_class)
  delete_ingress_clash_policy
  ztru = ZoneTxtRecordUpdater.new
  list.each { |i| migrate_ingress(ztru, i, target_ingress_class) }
ensure
  restore_ingress_clash_policy
end

def migrate_ingress(ztru, i, target_ingress_class)
  ingress = Ingress.new(
    namespace: i.fetch(:namespace),
    name: i.fetch(:ingress)
  )

  new_ingress = "#{ingress.name}-second"

  log "  Deploying ingress #{new_ingress} with class #{target_ingress_class} in namespace #{ingress.namespace}"
  ingress.deploy_copy(new_ingress, target_ingress_class)

  params = {
    namespace: ingress.namespace,
    ingress_name: new_ingress
  }

  ingress.hostnames.each do |domain|
    log "  Updating TXT record for #{domain}"
    ztru.update_txt_record_for_domain(params.merge(domain: domain))
  end
end

############################################################

target_ingress_class = "k8snginx"

ingresses = [
  {
    namespace: "dstest",
    ingress: "helloworld-rubyapp-ingress"
  }
]

main(ingresses, target_ingress_class)
log "Done"