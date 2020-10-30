#!/usr/bin/env ruby

# Create a copy of an ingress, named "[name]-second", changing only the ingress class

require_relative "../lib/ingress_migrator"

namespace, source_ingress, target_ingress_class = ARGV

raise "\nPlease supply 3 command-line parameters: namespace, source_ingress, target_ingress_class" \
  if target_ingress_class.nil?

ingress = Ingress.new(
  namespace: namespace,
  name: source_ingress
)

ingress.deploy_copy("#{source_ingress}-second", target_ingress_class)
