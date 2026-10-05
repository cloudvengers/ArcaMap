locals { # 이 모듈에서 공유할 로컬 값
  imagebuilder_agent_check = /* 이미지 OS·Agent 상태를 검사할 스크립트 */ <<-BASH
    set -euo pipefail
    . /etc/os-release
    test "$ID" = ubuntu
    test "$VERSION_ID" = 26.04
    test "$(uname -m)" = x86_64
    systemctl is-active --quiet amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status |
      python3 -c 'import json, sys; s = json.load(sys.stdin); assert s["status"] == "running" and s["version"] == "${var.cloudwatch_agent_version}", s'
  BASH
} # 설정 묶음 끝

resource "aws_imagebuilder_component" "base" { # 이미지 빌드·검증 구성요소 정의
  name     = "arcamap-base"                    # AWS 리소스·규칙·작업 이름
  platform = "Linux"                           # 이미지 구성요소의 운영체제 계열
  version  = var.image_builder_version         # Image Builder 구성요소·레시피 버전

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝

  data = yamlencode({                               # 빌드·검증 절차를 YAML 문서로 변환
    schemaVersion = "1.0"                           # Image Builder 구성요소 문서 형식 버전
    phases = [                                      # 이미지 빌드·검증 단계 목록
      {                                             # 목록 항목 설정 시작
        name = "build"                              # AWS 리소스·규칙·작업 이름
        steps = [{                                  # 빌드·검증 단계의 실행 작업 목록
          name           = "InstallCloudWatchAgent" # AWS 리소스·규칙·작업 이름
          action         = "ExecuteBash"            # Bash로 빌드·검증 명령 실행
          onFailure      = "Abort"                  # 빌드·검증 단계 실패 시 처리 방식
          timeoutSeconds = 600                      # 빌드·검증 작업 제한 시간(초)
          inputs = {                                # 빌드·검증 단계에 전달할 입력
            commands = [/* 이미지 빌드·검증에서 실행할 스크립트 */ <<-BASH
              set -euo pipefail
              command -v curl python3 dpkg systemctl logger
              package_dir=$(mktemp -d)
              trap 'rm -r -- "$package_dir"' EXIT
              curl --fail --silent --show-error --location --retry 3 --max-time 300 \
                --proto '=https' --proto-redir '=https' \
                "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/${var.cloudwatch_agent_version}/amazon-cloudwatch-agent.deb" \
                --output "$package_dir/amazon-cloudwatch-agent.deb"
              test "$(dpkg-deb --field "$package_dir/amazon-cloudwatch-agent.deb" Version)" = "${var.cloudwatch_agent_version}-1"
              test "$(dpkg-deb --field "$package_dir/amazon-cloudwatch-agent.deb" Architecture)" = amd64
              dpkg --install "$package_dir/amazon-cloudwatch-agent.deb"
              cat > /opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json <<'JSON'
              ${jsonencode(jsondecode(var.cloudwatch_agent_config_json))}
              JSON
              systemctl enable amazon-cloudwatch-agent
              ${var.cloudwatch_agent_start}
            BASH
            ]                                           # 설정 묶음 끝
          }                                             # 설정 묶음 끝
        }]                                              # 설정 묶음 끝
      },                                                # 설정 묶음 끝
      {                                                 # 목록 항목 설정 시작
        name = "validate"                               # AWS 리소스·규칙·작업 이름
        steps = [{                                      # 빌드·검증 단계의 실행 작업 목록
          name      = "ValidateOperatingSystemAndAgent" # AWS 리소스·규칙·작업 이름
          action    = "ExecuteBash"                     # Bash로 빌드·검증 명령 실행
          onFailure = "Abort"                           # 빌드·검증 단계 실패 시 처리 방식
          inputs = {                                    # 빌드·검증 단계에 전달할 입력
            commands = [local.imagebuilder_agent_check] # 이미지 빌드·검증에서 실행할 명령 목록
          }                                             # 설정 묶음 끝
        }]                                              # 설정 묶음 끝
      }                                                 # 설정 묶음 끝
    ]                                                   # 설정 묶음 끝
  })                                                    # 설정 묶음 끝
}                                                       # 설정 묶음 끝

resource "aws_imagebuilder_component" "test" { # 이미지 빌드·검증 구성요소 정의
  name     = "arcamap-agent-test"              # AWS 리소스·규칙·작업 이름
  platform = "Linux"                           # 이미지 구성요소의 운영체제 계열
  version  = var.image_builder_version         # Image Builder 구성요소·레시피 버전

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝

  data = yamlencode({                                                                                          # 빌드·검증 절차를 YAML 문서로 변환
    schemaVersion = "1.0"                                                                                      # Image Builder 구성요소 문서 형식 버전
    phases = [{                                                                                                # 이미지 빌드·검증 단계 목록
      name = "test"                                                                                            # AWS 리소스·규칙·작업 이름
      steps = [                                                                                                # 빌드·검증 단계의 실행 작업 목록
        {                                                                                                      # 목록 항목 설정 시작
          name      = "StartAndValidateAgent"                                                                  # AWS 리소스·규칙·작업 이름
          action    = "ExecuteBash"                                                                            # Bash로 빌드·검증 명령 실행
          onFailure = "Abort"                                                                                  # 빌드·검증 단계 실패 시 처리 방식
          inputs = {                                                                                           # 빌드·검증 단계에 전달할 입력
            commands = ["set -euo pipefail\n${var.cloudwatch_agent_start}\n${local.imagebuilder_agent_check}"] # 이미지 빌드·검증에서 실행할 명령 목록
          }                                                                                                    # 설정 묶음 끝
        },                                                                                                     # 설정 묶음 끝
        {                                                                                                      # 목록 항목 설정 시작
          name           = "VerifyJournaldDelivery"                                                            # AWS 리소스·규칙·작업 이름
          action         = "ExecuteBash"                                                                       # Bash로 빌드·검증 명령 실행
          onFailure      = "Abort"                                                                             # 빌드·검증 단계 실패 시 처리 방식
          timeoutSeconds = 600                                                                                 # 빌드·검증 작업 제한 시간(초)
          inputs = {                                                                                           # 빌드·검증 단계에 전달할 입력
            commands = [/* 이미지 빌드·검증에서 실행할 스크립트 */ <<-BASH
              set -euo pipefail
              python3 - <<'PY'
              import json
              import subprocess
              import time
              import urllib.request
              import uuid

              metadata = urllib.request.build_opener(urllib.request.ProxyHandler({}))
              token_request = urllib.request.Request(
                  "http://169.254.169.254/latest/api/token", method="PUT",
                  headers={"X-aws-ec2-metadata-token-ttl-seconds": "600"})
              with metadata.open(token_request, timeout=5) as response:
                  token = response.read().decode()

              def imds(path):
                  request = urllib.request.Request(
                      "http://169.254.169.254/latest/meta-data/" + path,
                      headers={"X-aws-ec2-metadata-token": token})
                  with metadata.open(request, timeout=5) as response:
                      return response.read().decode().strip()

              instance_id = imds("instance-id")
              role = imds("iam/security-credentials/")
              credentials = json.loads(imds("iam/security-credentials/" + role))
              # Pass credentials through stdin so they are absent from command arguments.
              authentication = (
                  "user = " + json.dumps(credentials["AccessKeyId"] + ":" + credentials["SecretAccessKey"]) + "\n"
                  "header = " + json.dumps("X-Amz-Security-Token: " + credentials["Token"]) + "\n")
              marker = "arcamap-imagebuilder-" + uuid.uuid4().hex
              request = {
                  "logGroupName": ${jsonencode(var.system_log_group_name)},
                  "logStreamNames": [instance_id + "/system"],
                  "filterPattern": '"' + marker + '"',
                  "startTime": int(time.time() * 1000),
              }
              subprocess.run(["logger", "--priority", "user.info", "--tag", "arcamap-imagebuilder-test", marker], check=True)
              deadline = time.monotonic() + 300
              while time.monotonic() < deadline:
                  response = subprocess.run(
                      ["curl", "--silent", "--show-error", "--fail-with-body",
                       "--connect-timeout", "5", "--max-time", "20",
                       "--aws-sigv4", "aws:amz:${data.aws_region.current.region}:logs", "--config", "-",
                       "--header", "Content-Type: application/x-amz-json-1.1",
                       "--header", "X-Amz-Target: Logs_20140328.FilterLogEvents",
                       "--data", json.dumps(request), "https://logs.${data.aws_region.current.region}.amazonaws.com/"],
                      input=authentication, capture_output=True, text=True)
                  if response.returncode:
                      if "ResourceNotFoundException" in response.stdout:
                          time.sleep(5)
                          continue
                      raise SystemExit("CloudWatch Logs query failed; check the test instance permissions and network.")
                  result = json.loads(response.stdout)
                  if any(marker in event["message"] for event in result.get("events", [])):
                      print("Verified journald delivery from " + instance_id)
                      break
                  if result.get("nextToken"):
                      request["nextToken"] = result["nextToken"]
                  else:
                      request.pop("nextToken", None)
                      time.sleep(5)
              else:
                  raise SystemExit("The journald test event was not received by CloudWatch Logs within 300 seconds.")
              PY
            BASH
            ] # 설정 묶음 끝
          }   # 설정 묶음 끝
        }     # 설정 묶음 끝
      ]       # 설정 묶음 끝
    }]        # 설정 묶음 끝
  })          # 설정 묶음 끝
}             # 설정 묶음 끝
