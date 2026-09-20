resource "aws_imagebuilder_component" "fastapi" {
  name     = "arcamap-fastapi"
  platform = "Linux"
  version  = var.image_builder_version

  data = yamlencode({
    schemaVersion = "1.0"
    phases = [
      {
        name = "build"
        steps = [{
          name           = "InstallFastAPI"
          action         = "ExecuteBash"
          onFailure      = "Abort"
          timeoutSeconds = 1200
          inputs = {
            commands = [<<-BASH
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
              install -d -m 0755 /opt/arcamap/was /opt/arcamap/python /etc/arcamap /usr/local/libexec
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
              printf '%s' '${var.api_installation.rds_ca_base64}' | base64 --decode > /etc/arcamap/rds-ap-northeast-2-bundle.pem
              printf '%s' '${var.api_installation.secret_loader_base64}' | base64 --decode > /usr/local/libexec/arcamap-load-environment
              chmod 0755 /usr/local/libexec/arcamap-load-environment
              printf '%s' '${var.api_installation.service_base64}' | base64 --decode > /etc/systemd/system/arcamap-api.service
              cat > /etc/arcamap/secret.env <<'ENV'
              AWS_REGION=${data.aws_region.current.region}
              ARCAMAP_SECRET_ID=${var.api_installation.secret_arn}
              ENV
              systemctl daemon-reload
              systemctl enable arcamap-api.service
            BASH
            ]
          }
        }]
      },
      {
        name = "validate"
        steps = [{
          name      = "ValidateFastAPIInstallation"
          action    = "ExecuteBash"
          onFailure = "Abort"
          inputs = {
            commands = [<<-BASH
              set -euo pipefail
              systemd-analyze verify /etc/systemd/system/arcamap-api.service
              systemctl is-enabled --quiet arcamap-api.service
              ! systemctl is-active --quiet arcamap-api.service
              test ! -e /etc/arcamap/runtime.env
              test ! -e /run/arcamap/runtime.env
              bash -n /usr/local/libexec/arcamap-load-environment
              cd /opt/arcamap/was
              runuser -u arcamap -- env PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -c 'import main, fastapi, psycopg, uvicorn; print("FastAPI imports OK")'
              printf '%s  %s\n' '${sha256(base64decode(var.api_installation.rds_ca_base64))}' /etc/arcamap/rds-ap-northeast-2-bundle.pem | sha256sum --check
            BASH
            ]
          }
        }]
      }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_imagebuilder_component" "fastapi_test" {
  name     = "arcamap-fastapi-test"
  platform = "Linux"
  version  = var.image_builder_version

  data = yamlencode({
    schemaVersion = "1.0"
    phases = [{
      name = "test"
      steps = [{
        name           = "VerifyFastAPIAutomaticStartupAndRDS"
        action         = "ExecuteBash"
        onFailure      = "Abort"
        timeoutSeconds = 240
        inputs = {
          commands = [<<-BASH
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
            curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8080/health/db > /tmp/arcamap-db-health.json
            /opt/arcamap/was/.venv/bin/python - <<'PY'
            import json
            for path in ("/tmp/arcamap-health.json", "/tmp/arcamap-db-health.json"):
                with open(path) as response:
                    assert json.load(response)["status"] == "ok", path
            print("FastAPI automatic startup and RDS SELECT 1 succeeded")
            PY
            test "$(stat -c '%U:%G:%a' /run/arcamap/runtime.env)" = root:root:600
            test "$(findmnt -n -o FSTYPE -T /run/arcamap/runtime.env)" = tmpfs
            test ! -e /etc/arcamap/runtime.env
            test "$(systemctl show arcamap-api.service --property=User --value)" = arcamap
          BASH
          ]
        }
      }]
    }]
  })

  lifecycle {
    create_before_destroy = true
  }
}
