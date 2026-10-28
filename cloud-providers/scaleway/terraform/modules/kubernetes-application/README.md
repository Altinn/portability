# kubernetes-application

Deploys one HTTP application as a Kubernetes Deployment and exposes it with a
public `LoadBalancer` Service. On Scaleway Kapsule the Cloud Controller Manager
creates the managed public Load Balancer and routes backend traffic through the
cluster Private Network.

The module also creates an application Secret and, when requested, a Docker
registry pull Secret for the private Scaleway Container Registry.

Kubernetes Secret values are stored in Terraform state. Treat the remote state
and saved plans as sensitive.

Pinned Kubernetes provider: 3.3.0.
