# Cloud Platform Ingress Migrator

Move ingresses on the cloud platform from one ingress controller to another, with zero downtime.

## Usage

### Create second ingress

Given an ingress `my-ingress` in namespace `my-namespace`, deploy a copy of it called `my-ingress-second` with ingress class `k8snginx` like this:

```
bin/copy-ingress.rb my-namespace my-ingress k8snginx
```

> This will fail unless the `ingress-clash` OPA policy has been disabled

### Change DNS

Given two ingresses `my-ingress` and `my-ingress-second` in the namespace `my-namespace`, where each ingress runs on a different ingress controller and handles traffic for the host `my.domain.name`, you can switch traffic from to the `my-ingress-second` ingress like this:

```
bin/update-txt-record-for-domain.rb my.domain.name my-namespace my-ingress-second
```

## Problem

Internet traffic is routed to services running on the Cloud Platform like this:

```
                         O
                    3   / \
             +--------  | |  user
             |          +-+
             |         1 | 2
             |           |
             |    +---------------+
             |    | Domain DNS A  |
             |    | record        |
             |    +---------------+
             |
             |
     +-----------------+
     | Load balancer 1 |
     | x.x.x.111       |
     +-----------------+
             |
             | Nginx
             | Ingress
             | Controller 1
     +-------|-------+
     |       |       |
     | +-----------+ |
     | | ingress-a | |
     | +-----------+ |
     |        \      |
     +---------\-----+
                \
                 \
                  \
             +------------------------+
             |        my-service      |
             +------------------------+
```

1. User accesses `https://my-service.domain.name`
2. Route53 DNS returns `x.x.x.111` the IP number of "Load balancer 1", which belongs to "Nginx Ingress Controller 1", which has "ingress-a" which handles traffic for the domain
3. User accesses "my-service" via "Load balancer 1" and "ingress-a" (which knows how to serve traffic for `my-service.domain.name`)

If we need to move "ingress-a" to a different ingress controller (which will have a different load-balancer), say "Ingress Controller 2", we can do so by deleting "ingress-a" from "Ingress Controller 1" and adding it to "Ingress Controller 2".

This is what happens automatically, via `external-dns`, if we change the ingress class of "ingress-a" from `ingress-controller-1` to `ingress-controller-2`.

So, we would have this situation:

```
                         O
                        / \  user
                        | |--------------+
                        +-+      3       |
                       1 | 2             |
                         |               |
                  +---------------+      |
                  | Domain DNS A  |      |
                  | record        |      |
                  +---------------+      |
                                         |
                                         |
     +-----------------+        +-----------------+
     | Load balancer 1 |        | Load balancer 2 |
     | x.x.x.111       |        | x.x.x.222       |
     +-----------------+        +-----------------+
                                        |
                Nginx                   | Nginx
                Ingress                 | Ingress
                Controller 1            | Controller 2
     +---------------+          +-------|-------+
     |               |          |       |       |
     |               |          | +-----------+ |
     |               |          | | ingress-a'| |
     |               |          | +-----------+ |
     |               |          |      /        |
     +---------------+          +-----/---------+
                                     /
                                    /
                                   /
             +------------------------+
             |        my-service      |
             +------------------------+
```

1. User accesses `https://my-service.domain.name`
2. Route53 DNS returns `x.x.x.222` the IP number of "Load balancer 2", which belongs to "Nginx Ingress Controller 2", which has "ingress-a'" which handles traffic for the domain
3. User accesses "my-service" via "Load balancer 2" and "ingress-a'"

The problem is that some users might have local DNS caches with `x.x.x.111` as the IP number for `https://my-service.domain.name`

Until these DNS caches expire, affected users will be trying to access `my-service` via "Load balancer 1" and "Nginx Ingress Controller 1" but "ingress-a" is no longer defined on "Nginx Ingress Controller 1", so when the web request for `https://my-service.domain.name` arrives, it will get a 404 error response.

## Solution

We need to add "ingress-a'" to "Nginx Ingress Controller 2", and update the Route53 DNS A record for `my-service.domain.name`, but **without** removing "ingress-a" from "Nginx Ingress Controller 1"

So, we will have this situation:

```
                         O
                        / \  user
                        | |--------------+
                        +-+      3       |
                       1 | 2             |
                         |               |
                  +---------------+      |
                  | Domain DNS A  |      |
                  | record        |      |
                  +---------------+      |
                                         |
                                         |
     +-----------------+        +-----------------+
     | Load balancer 1 |        | Load balancer 2 |
     | x.x.x.111       |        | x.x.x.222       |
     +-----------------+        +-----------------+
             |                          |
             | Nginx                    | Nginx
             | Ingress                  | Ingress
             | Controller 1             | Controller 2
     +---------------+          +-------|-------+
     |               |          |       |       |
     | +-----------+ |          | +-----------+ |
     | | ingress-a | |          | | ingress-a'| |
     | +-----------+ |          | +-----------+ |
     |        \      |          |      /        |
     +---------\-----+          +-----/---------+
                \                    /
                 \                  /
                  \                /
             +------------------------+
             |        my-service      |
             +------------------------+
```

So, the user can access `my-service` via **either** IP number. If traffic for `my-service.domain.name` arrives at "Nginx Ingress Controller 1" via "Load balancer 1", it still knows to route that request to `my-service`, and there are no 404 errors.

## Process

This process describes how we can move an ingress from one ingress controller to another, with no downtime due to DNS caching.

In this example, we are moving traffic for the domain `my-service.domain.name` from `controller-1` to `controller-2`. Traffic for this hostname is handled by `ingress-a` in the namespace `my-service-namespace`.

1. Remove the `ingress-clash` OPA policy, which blocks us from deploying multiple ingresses which define the same hostname

2. Deploy a second ingress, into the same `my-service-namespace` namespace, called `ingress-a-second`. This ingress should have an `ingress.class` annotation of `controller-2` so that it deploys on the `controller-2` ingress controller. Other than that, it should be identical to `ingress-a` (i.e. it should also serve traffic for `my-service.domain.name`)

3. In the Route53 hosted zone which contains records for `my-service.domain.name`, find the TXT record named:

```
_external_dns.my-service.domain.name
```

This record will have a value of:

```
"heritage=external-dns,external-dns/owner=live-1,external-dns/resource=ingress/my-service-namespace/ingress-a"
```

This is the TXT record that external-dns creates to indicate that it has made the necessary Route53 DNS changes to point the A record for `my-service.domain.name` to the correct load balancer, i.e. the load balancer which belongs to `controller-1`, the ingress controller which is hosting `ingress-a`

4. Modify this TXT record so that the value becomes:

```
"heritage=external-dns,external-dns/owner=live-1,external-dns/resource=ingress/my-service-namespace/ingress-a-second"
```

external-dns will see that the value of the A record no longer matches the ingress mentioned in that value, and it will update the A record to point to the load balancer belonging to `controller-2`

5. Wait for at least 60 seconds (the default DNS A record TTL) to ensure that all end-users' local DNS caches have the correct, `controller-2` IP number.

At this point, `controller-1` can be upgraded or replaced, with no impact on traffic to `my-service.domain.name`
