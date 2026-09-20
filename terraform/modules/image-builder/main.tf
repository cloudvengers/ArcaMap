data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  imagebuilder_agent_check = <<-BASH
    set -euo pipefail
    . /etc/os-release
    test "$ID" = ubuntu
    test "$VERSION_ID" = 26.04
    test "$(uname -m)" = x86_64
    systemctl is-active --quiet amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status |
      python3 -c 'import json, sys; s = json.load(sys.stdin); assert s["status"] == "running" and s["version"] == "${var.cloudwatch_agent_version}", s'
  BASH
}

resource "aws_imagebuilder_component" "base" {
  name     = "arcamap-base"
  platform = "Linux"
  version  = var.image_builder_version

  lifecycle {
    create_before_destroy = true
  }

  data = yamlencode({
    schemaVersion = "1.0"
    phases = [
      {
        name = "build"
        steps = [{
          name           = "InstallCloudWatchAgent"
          action         = "ExecuteBash"
          onFailure      = "Abort"
          timeoutSeconds = 600
          inputs = {
            commands = [<<-BASH
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
            ]
          }
        }]
      },
      {
        name = "validate"
        steps = [{
          name      = "ValidateOperatingSystemAndAgent"
          action    = "ExecuteBash"
          onFailure = "Abort"
          inputs = {
            commands = [local.imagebuilder_agent_check]
          }
        }]
      }
    ]
  })
}

resource "aws_imagebuilder_component" "test" {
  name     = "arcamap-agent-test"
  platform = "Linux"
  version  = var.image_builder_version

  lifecycle {
    create_before_destroy = true
  }

  data = yamlencode({
    schemaVersion = "1.0"
    phases = [{
      name = "test"
      steps = [
        {
          name      = "StartAndValidateAgent"
          action    = "ExecuteBash"
          onFailure = "Abort"
          inputs = {
            commands = ["set -euo pipefail\n${var.cloudwatch_agent_start}\n${local.imagebuilder_agent_check}"]
          }
        },
        {
          name           = "VerifyJournaldDelivery"
          action         = "ExecuteBash"
          onFailure      = "Abort"
          timeoutSeconds = 600
          inputs = {
            commands = [<<-BASH
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
            ]
          }
        }
      ]
    }]
  })
}

resource "aws_imagebuilder_image_recipe" "api" {
  name         = "arcamap-api"
  parent_image = data.aws_ami.ubuntu.id
  version      = var.image_builder_version

  component {
    component_arn = aws_imagebuilder_component.base.arn
  }

  component {
    component_arn = aws_imagebuilder_component.fastapi.arn
  }

  component {
    component_arn = aws_imagebuilder_component.test.arn
  }

  component {
    component_arn = aws_imagebuilder_component.fastapi_test.arn
  }

  lifecycle {
    create_before_destroy = true
  }

  block_device_mapping {
    device_name = data.aws_ami.ubuntu.root_device_name

    ebs {
      volume_type           = "gp3"
      volume_size           = var.image_builder_root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "api" {
  name                          = "arcamap-api"
  instance_profile_name         = var.image_builder_instance_profile_name
  instance_types                = [var.image_builder_instance_type]
  subnet_id                     = var.api_subnet_id
  security_group_ids            = [var.api_security_group_id]
  terminate_instance_on_failure = true

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

resource "aws_imagebuilder_image" "api" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.api.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.api.arn

  image_tests_configuration {
    image_tests_enabled = true
  }

  logging_configuration {
    log_group_name = var.imagebuilder_log_group_name
  }

  timeouts {
    create = "120m"
  }

  lifecycle {
    create_before_destroy = true
  }
}
