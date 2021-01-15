#!/usr/bin/env ruby

# Script to build the list of ingresses and its namespaces with
# the ingress-class annotations as "nginx" or empty i.e "" or ingress
# with no annotations and into a json file
# This script will list ingress for all non-prod namespaces. For production ingresses
# change if non_production?(namespace) to if production?(namespace)

require "json"
require "open3"

NGINX_CLASS_INGRESS_LIST_FILE = "nginx_class_ingresses.json"

def main
  $namespaces = get_namespaces

  nginx_class_ingresses = ingresses_matching_class("nginx")

  null_class_ingresses = ingresses_matching_class("")

  no_annotation_ingresses = ingresses_matching_no_class

  list = (nginx_class_ingresses + null_class_ingresses + no_annotation_ingresses).compact

  puts "Total ingress listed: #{list.size}"

  File.write(NGINX_CLASS_INGRESS_LIST_FILE, JSON.pretty_generate(list))
end

def ingresses_matching_class(target_ingress_class)
  ingress_array = []
  get_ingresses
    .filter { |ingress| ingress.dig("metadata", "annotations", "kubernetes.io/ingress.class").to_s == target_ingress_class }
    .map do |ingress|
    ingress_array.push(non_production_tuple(ingress))
  end
  ingress_array
end

def ingresses_matching_no_class
  ingress_array = []
  get_ingresses.reject { |ingress| ingress.dig("metadata").include?("annotations") }
    .map do |ingress|
    ingress_array.push(non_production_tuple(ingress))
  end
  ingress_array
end

def get_ingresses
  cmd = "kubectl get ingress -A -o json"

  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    raise stderr
  end

  JSON.parse(stdout).fetch("items")
end

def non_production_tuple(ingress)
  ingress_name = ingress.dig("metadata", "name")
  namespace = ingress.dig("metadata", "namespace")
  # To get the production list, change to !non_production?(namespace)
  if non_production?(namespace)
    {namespace: namespace, ingress_name: ingress_name}
  end
end

def get_namespaces
  json = `kubectl get namespaces -o json`
  JSON.parse(json).fetch("items")
end

def non_production?(namespace)
  ns = $namespaces.find { |n| n.dig("metadata", "name") == namespace }
  ns.dig("metadata", "labels", "cloud-platform.justice.gov.uk/is-production") == "false"
end

############################################################

main
