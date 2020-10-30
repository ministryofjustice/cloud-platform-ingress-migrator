class Ingress
  attr_reader :namespace, :name

  def initialize(params)
    @namespace = params.fetch(:namespace)
    @name = params.fetch(:name)
  end

  def hostnames
    data.dig("spec", "rules").map { |r| r.fetch("host") }
  end

  def data
    @data ||= begin
                cmd = %[kubectl --namespace #{namespace} get ingress #{name} -o json]
                json = `#{cmd}`
                raise "\nCould not find ingress #{name} in namespace #{namespace}" if json == ""
                JSON.parse(json)
              end
  end
end
