require "bundler/setup"
require "aws-sdk-route53"
require "json"

require_relative "./ingress"
require_relative "./zone_txt_record_updater"
