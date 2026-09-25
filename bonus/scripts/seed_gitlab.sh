#!/bin/bash
# ============================================================================
#  Seeds the local GitLab instance:
#    - creates the PUBLIC project  root/iot   (public => Argo CD clones it
#      anonymously, exactly like the GitHub repository of Part 3)
#    - commits confs/app into it (the manifests Argo CD will sync)
#    - creates a personal access token, saved in bonus/.gitlab-token, used by
#      switch_version.sh to clone/push from the host
#
#  Everything goes through gitlab-rails inside the GitLab pod, which is the
#  supported way to administrate an omnibus GitLab.
#
#  Called by setup.sh, can be replayed alone:  sudo ./scripts/seed_gitlab.sh
# ============================================================================
set -euo pipefail

GITLAB_HOST="${GITLAB_HOST:-gitlab.local}"
GITLAB_NAMESPACE="${GITLAB_NAMESPACE:-gitlab}"
PROJECT_PATH="root/iot"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${SCRIPT_DIR}/../confs"
TOKEN_FILE="${SCRIPT_DIR}/../.gitlab-token"

log() { echo -e "\n==> $*"; }

POD="$(kubectl -n "${GITLAB_NAMESPACE}" get pod -l app=gitlab \
        -o jsonpath='{.items[0].metadata.name}')"

if [ -s "${TOKEN_FILE}" ]; then
    TOKEN="$(cat "${TOKEN_FILE}")"
else
    TOKEN="glpat-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi

# The manifests live on the host: ship them to the pod, base64 encoded.
README_CONTENT=$(cat <<'EOF'
# IoT - bonus

Manifests deployed by Argo CD from this local GitLab instance.

Change the image tag in `confs/app/deployment.yaml` (v1 <-> v2) and commit:
Argo CD syncs the `dev` namespace automatically.
EOF
)

log "Creating the public project ${PROJECT_PATH} and pushing the manifests..."

run_seed() {
    kubectl -n "${GITLAB_NAMESPACE}" exec -i "${POD}" -- env \
        IOT_TOKEN="${TOKEN}" \
        IOT_README="$(printf '%s' "${README_CONTENT}" | base64 -w0)" \
        IOT_DEPLOYMENT="$(base64 -w0 "${CONF_DIR}/app/deployment.yaml")" \
        IOT_SERVICE="$(base64 -w0 "${CONF_DIR}/app/service.yaml")" \
        IOT_INGRESS="$(base64 -w0 "${CONF_DIR}/app/ingress.yaml")" \
        gitlab-rails runner - <<'RUBY'
require 'base64'

user = User.find_by_username('root')
abort 'root user not found' if user.nil?

# ---- public project -------------------------------------------------------
project = Project.find_by_full_path('root/iot')
if project.nil?
  project = ::Projects::CreateService.new(user, {
    name: 'iot',
    path: 'iot',
    namespace_id: user.namespace.id,
    visibility_level: Gitlab::VisibilityLevel::PUBLIC,
    initialize_with_readme: false
  }).execute
  abort("project creation failed: #{project.errors.full_messages.join(', ')}") unless project.persisted?
elsif !project.public?
  project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
end

# ---- first commit ---------------------------------------------------------
files = {
  'README.md'                  => Base64.decode64(ENV['IOT_README']),
  'confs/app/deployment.yaml'  => Base64.decode64(ENV['IOT_DEPLOYMENT']),
  'confs/app/service.yaml'     => Base64.decode64(ENV['IOT_SERVICE']),
  'confs/app/ingress.yaml'     => Base64.decode64(ENV['IOT_INGRESS'])
}

if project.repository.empty?
  files.each do |path, content|
    project.repository.create_file(user, path, content,
      message: "Add #{path}", branch_name: 'main')
  end
  begin
    project.change_head('main') unless project.default_branch == 'main'
  rescue StandardError => e
    puts "WARN could not set the default branch: #{e.message}"
  end
  puts 'SEEDED'
else
  puts 'ALREADY_SEEDED'
end

# ---- access token (for the clone/push demo from the host) -----------------
begin
  user.personal_access_tokens.find_by(name: 'iot-bonus')&.revoke!
  pat = PersonalAccessToken.new(
    user: user,
    name: 'iot-bonus',
    scopes: %w[api write_repository],
    expires_at: 90.days.from_now
  )
  if pat.respond_to?(:organization=) && defined?(Organizations::Organization)
    pat.organization = user.namespace.try(:organization) ||
                       Organizations::Organization.default_organization
  end
  pat.set_token(ENV['IOT_TOKEN'])
  pat.save!
  puts 'TOKEN_OK'
rescue StandardError => e
  puts "TOKEN_FAILED #{e.message}"
end
RUBY
}

attempt=1
OUTPUT=""
until OUTPUT="$(run_seed 2>&1)" && echo "${OUTPUT}" | grep -qE 'SEEDED|ALREADY_SEEDED'; do
    echo "${OUTPUT}"
    attempt=$((attempt + 1))
    if [ "${attempt}" -gt 3 ]; then
        echo "Could not seed GitLab."
        exit 1
    fi
    echo "    retrying (${attempt}/3) in 30s..."
    sleep 30
done
echo "${OUTPUT}"

if echo "${OUTPUT}" | grep -q 'TOKEN_OK'; then
    umask 077
    echo "${TOKEN}" > "${TOKEN_FILE}"
    echo "    access token saved in ${TOKEN_FILE}"
else
    echo "    WARNING: no access token could be created."
    echo "    Create one in http://${GITLAB_HOST}/-/user_settings/personal_access_tokens"
    echo "    (scope write_repository) and write it into ${TOKEN_FILE}."
fi

echo "    repository ready: http://${GITLAB_HOST}/${PROJECT_PATH}"
