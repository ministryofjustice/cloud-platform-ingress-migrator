tail-default-ingress:
	stern -n ingress-controllers -l "app=nginx-ingress" | grep dstest-helloworld-rubyapp
tail-k8snginx-ingress:
	stern -n ingress-controllers -l "app.kubernetes.io/instance=k8snginx" | grep dstest-helloworld-rubyapp
curl-the-app:
	while true; do curl -sI https://dstest-helloworld-rubyapp.apps.live-1.cloud-platform.service.justice.gov.uk/ | head -2; sleep 5; done
tail-pod-logs:
	kubectl -n dstest logs helloworld-rubyapp-58f6b9d74d-dbm8s -f
# https://console.aws.amazon.com/route53/v2/hostedzones#ListRecordSets/Z28AFU7GYHT7R4

