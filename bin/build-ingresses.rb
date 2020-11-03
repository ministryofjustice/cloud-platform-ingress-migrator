#!/usr/bin/env ruby

# Script to migrate multiple ingresses to a different ingress controller, by
# deploying a second ingress on that controller, and updating the route53 TXT
# record for each of the ingress's hostnames

# TODO: remove this
require "pry-byebug"
require "json"
require "open3"


def main()
  nginx_class_ingresses = build_ingresses_has_annotations("nginx")
  null_class_ingresses = build_ingresses_has_annotations("")

  File.open("ingress_list.txt", "w+") do |f|
    f.puts(nginx_class_ingresses.inspect)
  end
  # TODO Check if the migration script copy ingress which has no annotations 
  puts "Ingress with no annotations"
  puts build_ingresses_no_annotations
end 


def build_ingresses_has_annotations(target_ingress_class)
  ingress_array = []
  get_ingresses.map { |ingress| 
  if(ingress.dig("metadata").include?("annotations"))
    if(ingress.dig("metadata","annotations","kubernetes.io/ingress.class").to_s == target_ingress_class)
      ingress_name = ingress.dig("metadata","name")
      namespace = ingress.dig("metadata","namespace")
      ingress_array.push({namespace: namespace, ingress_name: ingress_name})
    end
  end
}
ingress_array
end


def build_ingresses_no_annotations
  ingress_array = []  
  get_ingresses.map { |ingress| 
  if(!ingress.dig("metadata").include?("annotations"))
    ingress_name = ingress.dig("metadata","name")
    namespace = ingress.dig("metadata","namespace")
    ingress_array.push({namespace: namespace, ingress_name: ingress_name})
  end
}
ingress_array
end

def get_ingresses
  cmd = "kubectl get ingress --all-namespaces -o json"

  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    raise stderr
  end

  JSON.parse(stdout).fetch("items")
end

############################################################

main

