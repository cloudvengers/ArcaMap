module "network" {
  source = "../../modules/network"
}

module "security" {
  source = "../../modules/security"

  vpc_id = module.network.vpc_id
}
