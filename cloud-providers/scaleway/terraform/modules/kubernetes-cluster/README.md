# kubernetes-cluster

Creates a Scaleway Kapsule cluster and one application node pool attached to an
existing Private Network. The default uses controlled isolation: worker nodes
have private addresses for east/west traffic and public addresses for outbound
internet access, while inbound traffic remains blocked by the Kapsule security
group unless exposed through Kubernetes services.

The module exports kubeconfig connection values for a Kubernetes provider in the
calling root. The kubeconfig output is sensitive and waits for the node pool to
be ready.

Pinned Scaleway provider: 2.86.0.
