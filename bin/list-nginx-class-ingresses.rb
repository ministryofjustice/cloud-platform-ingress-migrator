#!/usr/bin/env ruby

# Script to build the list of ingresses and its namespaces with
# the ingress-class annotations as "nginx" or empty i.e "" or ingress
# with no annotations and into a json file

require "json"
require "open3"

NGINX_CLASS_INGRESS_LIST_FILE = "nginx_class_ingresses.json"

def main
  nginx_class_ingresses = list_ingresses_has_annotations("nginx")
  null_class_ingresses = list_ingresses_has_annotations("")
  no_annotation_ingresses = list_ingresses_no_annotations
  list = nginx_class_ingresses + null_class_ingresses + no_annotation_ingresses

  puts "Total ingress listed "
  puts list.size
  File.write(NGINX_CLASS_INGRESS_LIST_FILE, JSON.pretty_generate(list))
end

def list_ingresses_has_annotations(target_ingress_class)
  ingress_array = []
  get_ingresses.map do |ingress|
    if ingress.dig("metadata").include?("annotations")
      if ingress.dig("metadata", "annotations", "kubernetes.io/ingress.class").to_s == target_ingress_class
        ingress_name = ingress.dig("metadata", "name")
        namespace = ingress.dig("metadata", "namespace")
        if check_is_production(namespace).include?("false")
          ingress_array.push({namespace: namespace, ingress_name: ingress_name})
        end
      end
    end
  end
  ingress_array
end

def list_ingresses_no_annotations
  ingress_array = []
  get_ingresses.map do |ingress|
    unless ingress.dig("metadata").include?("annotations")
      ingress_name = ingress.dig("metadata", "name")
      namespace = ingress.dig("metadata", "namespace")
      if check_is_production(namespace).include?("false")
        ingress_array.push({namespace: namespace, ingress_name: ingress_name})
      end
    end
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

def check_is_production(namespace)
  cmd = "kubectl get ns #{namespace} -o json | jq '[.metadata.labels[\"cloud-platform.justice.gov.uk/is-production\"]]'"

  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    raise stderr
  end
  JSON.parse(stdout)[0]
end

############################################################

main
