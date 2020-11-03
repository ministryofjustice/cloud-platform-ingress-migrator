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

  nginx_class_ingresses.concat(null_class_ingresses)
  nginx_class_ingresses.concat(no_annotation_ingresses)

  File.write(NGINX_CLASS_INGRESS_LIST_FILE, nginx_class_ingresses.to_json)
end

def list_ingresses_has_annotations(target_ingress_class)
  ingress_array = []
  get_ingresses.map do |ingress|
    if ingress.dig("metadata").include?("annotations")
      if ingress.dig("metadata", "annotations", "kubernetes.io/ingress.class").to_s == target_ingress_class
        ingress_name = ingress.dig("metadata", "name")
        namespace = ingress.dig("metadata", "namespace")
        ingress_array.push({namespace: namespace, ingress_name: ingress_name})
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
      ingress_array.push({namespace: namespace, ingress_name: ingress_name})
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

############################################################

main
