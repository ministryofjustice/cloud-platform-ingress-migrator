class Ingress
  attr_reader :namespace, :name

  def initialize(params)
    @namespace = params.fetch(:namespace)
    @name = params.fetch(:name)
  end

  def hostnames
    data.dig("spec", "rules").map { |r| r.fetch("host") }
  end

  def deploy_copy(ingress_name, ingress_class)
    ingress = deep_copy(data)
    delete_unneeded_ingress_attributes(ingress)

    # Set the new ingress class and name
    m = ingress.fetch("metadata")

    m["annotations"] = {} unless m.has_key?("annotations")
    m.fetch("annotations")["kubernetes.io/ingress.class"] = ingress_class
    m["name"] = ingress_name

    kube_deploy_json(ingress.to_json)
  end

  private

  def delete_unneeded_ingress_attributes(ingress)
    # Discard the extra data returned by the k8s API which we don't need in the copy
    ingress.delete("status")
    m = ingress.fetch("metadata")
    %w[creationTimestamp generation resourceVersion selfLink uid].each { |key| m.delete(key) }
    m.fetch("annotations").delete("kubectl.kubernetes.io/last-applied-configuration") if m.has_key?("annotations")
  end

  def kube_deploy_json(json)
    file = Tempfile.new("ingress.json")
    file.write json
    file.rewind
    `kubectl apply -f #{file.path}`
  ensure
    file.close
    file.unlink
  end

  def data
    @data ||= begin
      cmd = %(kubectl --namespace #{namespace} get ingress #{name} -o json)
      json = `#{cmd}`
      raise "\nCould not find ingress #{name} in namespace #{namespace}" if json == ""
      JSON.parse(json)
    end
  end

  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end
end
