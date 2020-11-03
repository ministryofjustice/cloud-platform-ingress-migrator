#!/usr/bin/env ruby

# Script to delete ingresses which has the ingress-class: "k8snginx".
# When running the migrate-ingresses.rb, it created a second ingress
# to be used by second/fallback ingress controller k8snginx. This has to be cleaned
# after the ingress controller is upgraded and all traffic is moved to 
# upgraded ingress controller.

require "json"
require "open3"

def main(ingress_list_file)

  second_ingresses_list = JSON.parse(File.read(ingress_list_file))
  second_ingresses_list.each { |i| delete_ingress(i) }
end

def delete_ingress(i)
  namespace = i.fetch("namespace")
  name = i.fetch("ingress_name")

  cmd = "kubectl delete ingress #{name} -n #{namespace}"
  puts cmd

  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    raise stderr
  end
end

############################################################

ingress_list_file = ARGV.shift
raise "No file with ingress and namespace list is supplied" if ingress_list_file.nil?
main ingress_list_file
