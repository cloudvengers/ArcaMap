resource "aws_imagebuilder_component" "fastapi" { # 이미지 빌드·검증 구성요소 정의
  name     = "arcamap-fastapi"                    # AWS 리소스·규칙·작업 이름
  platform = "Linux"                              # 이미지 구성요소의 운영체제 계열
  version  = var.image_builder_version            # Image Builder 구성요소·레시피 버전

  data = yamlencode({                       # 빌드·검증 절차를 YAML 문서로 변환
    schemaVersion = "1.0"                   # Image Builder 구성요소 문서 형식 버전
    phases = [                              # 이미지 빌드·검증 단계 목록
      {                                     # 목록 항목 설정 시작
        name = "build"                      # AWS 리소스·규칙·작업 이름
        steps = [{                          # 빌드·검증 단계의 실행 작업 목록
          name           = "InstallFastAPI" # AWS 리소스·규칙·작업 이름
          action         = "ExecuteBash"    # Bash로 빌드·검증 명령 실행
          onFailure      = "Abort"          # 빌드·검증 단계 실패 시 처리 방식
          timeoutSeconds = 1200             # 빌드·검증 작업 제한 시간(초)
          inputs = {                        # 빌드·검증 단계에 전달할 입력
            commands = [/* 이미지 빌드·검증에서 실행할 스크립트 */ <<-BASH
              set -euo pipefail
              package_dir=$(mktemp -d)
              trap 'rm -r -- "$package_dir"' EXIT
              curl --fail --silent --show-error --location --retry 3 --max-time 300 \
                --proto '=https' --proto-redir '=https' \
                https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip --output "$package_dir/awscli.zip"
              python3 -m zipfile -e "$package_dir/awscli.zip" "$package_dir"
              chmod 0755 "$package_dir/aws/install" "$package_dir/aws/dist/aws" "$package_dir/aws/dist/aws_completer"
              "$package_dir/aws/install"
              /usr/local/bin/aws --version
              /usr/local/bin/aws s3 cp '${var.api_installation.artifact_uri}' "$package_dir/was.tar.gz" --only-show-errors
              printf '%s  %s\n' '${var.api_installation.artifact_sha256}' "$package_dir/was.tar.gz" | sha256sum --check
              useradd --system --user-group --home-dir /opt/arcamap --no-create-home --shell /usr/sbin/nologin arcamap
              install -d -m 0755 /opt/arcamap/was /opt/arcamap/python /etc/arcamap
              tar --extract --gzip --file "$package_dir/was.tar.gz" --directory /opt/arcamap/was --no-same-owner
              curl --fail --silent --show-error --location --retry 3 --max-time 300 \
                --proto '=https' --proto-redir '=https' \
                https://github.com/astral-sh/uv/releases/download/0.12.12/uv-x86_64-unknown-linux-gnu.tar.gz \
                --output "$package_dir/uv.tar.gz"
              curl --fail --silent --show-error --location --retry 3 --max-time 60 \
                --proto '=https' --proto-redir '=https' \
                https://github.com/astral-sh/uv/releases/download/0.12.12/uv-x86_64-unknown-linux-gnu.tar.gz.sha256 \
                --output "$package_dir/uv.sha256"
              printf '%s  %s\n' "$(cut -d ' ' -f 1 "$package_dir/uv.sha256")" "$package_dir/uv.tar.gz" | sha256sum --check
              tar --extract --gzip --file "$package_dir/uv.tar.gz" --directory "$package_dir"
              install -m 0755 "$package_dir/uv-x86_64-unknown-linux-gnu/uv" /usr/local/bin/uv
              export UV_PYTHON_INSTALL_DIR=/opt/arcamap/python UV_CACHE_DIR="$package_dir/uv-cache"
              cd /opt/arcamap/was
              uv python install 3.14.7
              uv sync --locked --no-dev --python 3.14.7 --no-editable
              chmod -R a+rX /opt/arcamap
              test -s /etc/ssl/certs/Amazon_Root_CA_1.pem
              openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/Amazon_Root_CA_1.pem
              printf '%s' '${var.api_installation.environment_base64}' | base64 --decode > /etc/arcamap/runtime.env
              chmod 0644 /etc/arcamap/runtime.env
              printf '%s' '${var.api_installation.service_base64}' | base64 --decode > /etc/systemd/system/arcamap-api.service
              systemctl daemon-reload
              systemctl enable arcamap-api.service
            BASH
            ]                                       # 설정 묶음 끝
          }                                         # 설정 묶음 끝
        }]                                          # 설정 묶음 끝
      },                                            # 설정 묶음 끝
      {                                             # 목록 항목 설정 시작
        name = "validate"                           # AWS 리소스·규칙·작업 이름
        steps = [{                                  # 빌드·검증 단계의 실행 작업 목록
          name      = "ValidateFastAPIInstallation" # AWS 리소스·규칙·작업 이름
          action    = "ExecuteBash"                 # Bash로 빌드·검증 명령 실행
          onFailure = "Abort"                       # 빌드·검증 단계 실패 시 처리 방식
          inputs = {                                # 빌드·검증 단계에 전달할 입력
            commands = [/* 이미지 빌드·검증에서 실행할 스크립트 */ <<-BASH
              set -euo pipefail
              systemd-analyze verify /etc/systemd/system/arcamap-api.service
              systemctl is-enabled --quiet arcamap-api.service
              ! systemctl is-active --quiet arcamap-api.service
              test -s /etc/arcamap/runtime.env
              test ! -e /run/arcamap/runtime.env
              test ! -e /usr/local/libexec/arcamap-load-environment
              cd /opt/arcamap/was
              runuser -u arcamap -- env PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -c 'import main, fastapi, psycopg, uvicorn, aurora_dsql_psycopg; print("FastAPI imports OK")'
              printf '%s  %s\n' '${sha256(base64decode(var.api_installation.environment_base64))}' /etc/arcamap/runtime.env | sha256sum --check
            BASH
            ] # 설정 묶음 끝
          }   # 설정 묶음 끝
        }]    # 설정 묶음 끝
      }       # 설정 묶음 끝
    ]         # 설정 묶음 끝
  })          # 설정 묶음 끝

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝
}                                # 설정 묶음 끝

resource "aws_imagebuilder_component" "fastapi_test" { # 이미지 빌드·검증 구성요소 정의
  name     = "arcamap-fastapi-test"                    # AWS 리소스·규칙·작업 이름
  platform = "Linux"                                   # 이미지 구성요소의 운영체제 계열
  version  = var.image_builder_version                 # Image Builder 구성요소·레시피 버전

  data = yamlencode({                                           # 빌드·검증 절차를 YAML 문서로 변환
    schemaVersion = "1.0"                                       # Image Builder 구성요소 문서 형식 버전
    phases = [{                                                 # 이미지 빌드·검증 단계 목록
      name = "test"                                             # AWS 리소스·규칙·작업 이름
      steps = [{                                                # 빌드·검증 단계의 실행 작업 목록
        name           = "VerifyFastAPIAutomaticStartupAndDSQL" # AWS 리소스·규칙·작업 이름
        action         = "ExecuteBash"                          # Bash로 빌드·검증 명령 실행
        onFailure      = "Abort"                                # 빌드·검증 단계 실패 시 처리 방식
        timeoutSeconds = 240                                    # 빌드·검증 작업 제한 시간(초)
        inputs = {                                              # 빌드·검증 단계에 전달할 입력
          commands = [/* 이미지 빌드·검증에서 실행할 스크립트 */ <<-BASH
            set -euo pipefail
            systemctl is-enabled --quiet arcamap-api.service
            # 새 테스트 EC2의 부팅 결과를 검사합니다. 서비스를 수동으로 시작하지 않습니다.
            for attempt in $(seq 1 30); do
              if systemctl is-active --quiet arcamap-api.service &&
                curl --fail --silent --max-time 10 http://127.0.0.1:8080/health > /tmp/arcamap-health.json; then
                break
              fi
              sleep 5
            done
            systemctl is-active --quiet arcamap-api.service
            # 빌드 IAM role은 운영 DB role과 별도로 매핑합니다. 이 drop-in은 테스트 EC2의 tmpfs에만 남습니다.
            install -d -m 0755 /run/systemd/system/arcamap-api.service.d
            printf '%s\n' 'PGUSER=${var.api_installation.db_test_user}' > /run/arcamap-imagebuilder.env
            chmod 0600 /run/arcamap-imagebuilder.env
            cat > /run/systemd/system/arcamap-api.service.d/imagebuilder.conf <<'UNIT'
            [Service]
            EnvironmentFile=/run/arcamap-imagebuilder.env
            UNIT
            systemctl daemon-reload
            systemctl restart arcamap-api.service
            for attempt in $(seq 1 30); do
              if curl --fail --silent --max-time 5 http://127.0.0.1:8080/health > /tmp/arcamap-health.json; then
                break
              fi
              sleep 1
            done
            curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8080/health/db > /tmp/arcamap-db-health.json
            /opt/arcamap/was/.venv/bin/python - <<'PY'
            import json
            for path in ("/tmp/arcamap-health.json", "/tmp/arcamap-db-health.json"):
                with open(path) as response:
                    assert json.load(response)["status"] == "ok", path
            print("FastAPI automatic startup and DSQL SELECT 1 succeeded")
            PY
            test "$(stat -c '%U:%G:%a' /etc/arcamap/runtime.env)" = root:root:644
            test "$(systemctl show arcamap-api.service --property=User --value)" = arcamap
          BASH
          ] # 설정 묶음 끝
        }   # 설정 묶음 끝
      }]    # 설정 묶음 끝
    }]      # 설정 묶음 끝
  })        # 설정 묶음 끝

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝
}                                # 설정 묶음 끝
