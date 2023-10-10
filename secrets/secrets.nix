let
  kenobi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
  linode1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJW41FXloY8w4tjYHbnfsopvpc8USCoSDsRKlInYbJkh root@linode1";
  share1 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvxlv9Oa/tRPLdXqeYxNAuS0V6com5sHqzVZSJ2AYnc+D3JkgpUyayaLOq16qdLGMh7ojLKc5+jk0qBekns/iSqT1MRE5//U5RqHcy6P85Z+JDxuILMRfAn+ub820zjN9kODjKsYHLS2V8xE15R8lWA16SK6OtU3PxdwfL0+Ulxf+ixljyJzSiD7bteIZDg80xmeRaI2FCrXGkh/rLroSHP48ukJ//K+DIR/BZjG6jQERbxkAwsdBTgqwzn3FlQvduo4rkEPrTFxserZxZanMuRRkyJ8O623e2Gs9gPJqsqUGxStBYXLpANcPr24b1PDPqKubJAp3R5QuUFbd8ZD326dziw9GTkAghVcyHjzN2qiPear8xr3FyGtUlHL+6tCnImklZfXg/KF0vlHUk/GAQ5xfV5zft/PvHzMFNdottWKbQ5nIJpOS+gG7HtfuNTDnAlnabtmLVcr2xgbzJwLmdCl8ZFmNkkpfQqWGD60pGC9WL3lSy9SkKVYlCjMO8k7s= jackson@share1";
in
{
  "share1-auth-key1.age".publicKeys = [ kenobi share1 ];
  "wireless.age".publicKeys = [ kenobi share1 ];
}
