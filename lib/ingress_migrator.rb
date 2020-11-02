require "tempfile"
require "bundler/setup"
require "aws-sdk-route53"
require "json"

require_relative "./ingress"
require_relative "./zone_txt_record_updater"

INGRESS_CLASH_BACKUP_FILE = "/tmp/policy-ingress-clash.yaml"

def delete_ingress_clash_policy
  policy = "policy-ingress-clash"
  log "Deleting OPA policy #{policy}"
  `kubectl -n opa get configmap #{policy} -o yaml > #{INGRESS_CLASH_BACKUP_FILE}`
  `kubectl -n opa delete configmap #{policy}`
end

def restore_ingress_clash_policy
  log "Restoring OPA policy"
  `kubectl -n opa apply -f #{INGRESS_CLASH_BACKUP_FILE}`
end

def log(msg)
  t = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  puts [t, msg].join(" ")
end
