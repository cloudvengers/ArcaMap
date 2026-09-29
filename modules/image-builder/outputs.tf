output "image" {                                                                   # image 정보를 호출자에게 반환
  description = "서울 리전에 빌드한 AMI ID와 루트 장치·최소 볼륨 용량."                               # 반환하는 값의 의미
  value = {                                                                        # 호출자에게 전달할 값
    id = one([                                                                     # 호출자에게 전달할 리소스 ID
      for ami in one(aws_imagebuilder_image.api.output_resources).amis : ami.image # 리전별 빌드 결과에서 AMI ID 추출
      if ami.region == data.aws_region.current.region                              # 현재 AWS 리전의 AMI만 선택
    ])                                                                             # 설정 묶음 끝
    root_device_name = data.aws_ami.ubuntu.root_device_name                        # AMI의 루트 블록 장치 이름
    root_volume_size = var.image_builder_root_volume_size                          # AMI 루트 볼륨 용량(GiB)
  }                                                                                # 설정 묶음 끝
}                                                                                  # 설정 묶음 끝
