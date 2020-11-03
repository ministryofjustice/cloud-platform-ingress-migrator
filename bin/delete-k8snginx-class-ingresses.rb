#!/usr/bin/env ruby

# Script to migrate multiple ingresses to a different ingress controller, by
# deploying a second ingress on that controller, and updating the route53 TXT
# record for each of the ingress's hostnames

# TODO: remove this
require "pry-byebug"
require "json"
require "open3"

def main
  second_ingresses_list = JSON.parse(File.read("k8snginx-class-ingresses.json"))
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

main
