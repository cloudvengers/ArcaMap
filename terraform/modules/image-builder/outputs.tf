output "image" {
  description = "서울 리전에 빌드한 AMI ID와 루트 장치·최소 볼륨 용량."
  value = {
    id = one([
      for ami in one(aws_imagebuilder_image.api.output_resources).amis : ami.image
      if ami.region == data.aws_region.current.region
    ])
    root_device_name = data.aws_ami.ubuntu.root_device_name
    root_volume_size = var.image_builder_root_volume_size
  }
}
