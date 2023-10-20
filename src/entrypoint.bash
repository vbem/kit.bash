#!/usr/bin/env bash

[[ -v _KIT_BASH ]] && return # avoid duplicated source
_KIT_BASH="$(realpath "${BASH_SOURCE[0]}")"; declare -rg _KIT_BASH # sourced sential

# Log to stderr
#   $1: level string
#   $2: message string
#   stderr: message string
function kit::log::stderr {
    local level
    case "$1" in
        FATAL|ERR*)     level="\e[1;91m$1\e[0m" ;;
        WARN*)          level="\e[1;95m$1\e[0m" ;;
        INFO*|NOTICE)   level="\e[1;92m$1\e[0m" ;;
        DEBUG)          level="\e[1;96m$1\e[0m" ;;
        *)              level="\e[1;94m$1\e[0m" ;;
    esac
    echo -e "\e[2;97m[\e[0m$level\e[2;97m]\e[0m \e[93m$2\e[0m" >&2
}

# Group stdin to stderr with title
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines
#   $1: group title
#   stdin: logs
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::wf::group {
    echo "::group::$1"      >&2
    echo "$(< /dev/stdin)"  >&2
    echo '::endgroup::'     >&2
}

# Masking a value in a log
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#masking-a-value-in-a-log
# https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-secrets
#   $1: value
function kit::wf::mask {
    echo "::add-mask::$1" >&2
}

# Stopping and starting workflow commands
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#stopping-and-starting-workflow-commands
#   $1: non-empty to resume
function kit::wf::stop {
    if [[ -z "$1" ]]; then
        echo '::stop-commands::__KIT_WF_STOP__' >&2
    else
        echo '::__KIT_WF_STOP__::' >&2
    fi
}

# Set stdin as value to output of current step with given name
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
# https://renehernandez.io/snippets/multiline-strings-as-a-job-output-in-github-actions/
#   $1: output name
#   $2: masked value in logs
#   stdin: output value
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::wf::output {
    local val
    val="$(< /dev/stdin)"
    { # https://www.gnu.org/software/bash/manual/bash.html#Command-Grouping
        echo "$1<<__GITHUB_OUTPUT__"
        echo "$val"
        echo '__GITHUB_OUTPUT__'
    } >> "$GITHUB_OUTPUT"
    kit::wf::group "🖨️ step output '$1' has been set" <<< "${2:-$val}"
}

# Set stdin as value to environment with given name
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
#   $1: environment variable name
#   $2: masked value in logs
#   stdin: environment variable value
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::wf::env {
    local val
    val="$(< /dev/stdin)"
    { # https://www.gnu.org/software/bash/manual/bash.html#Command-Grouping
        echo "$1<<__GITHUB_ENV__"
        echo "$val"
        echo '__GITHUB_ENV__'
    } >> "$GITHUB_ENV"
    kit::wf::group "💲 env '$1' has been set in \$GITHUB_ENV" <<< "${2:-$val}"
}

# Append summary content for the current step
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-markdown-content
#   stdin: markdown-content
#   $?: 0 if successful and non-zero otherwise
function kit::wf::summary {
    echo "$(< /dev/stdin)" >> "$GITHUB_STEP_SUMMARY"
}

# Prepend a directory to the system PATH variable to all subsequent actions in the current job
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#adding-a-system-path
#   $1: path
#   $?: 0 if successful and non-zero otherwise
function kit::wf::path {
    echo "$1" >> "$GITHUB_PATH"
}

# Flatten JSON to key-value lines
#   $1: separator (default as ' 👉 ')
#   stdin: json
#   stdout: flattened key-value lines
#   $?: 0 if successful and non-zero otherwise
function kit::json::flatten {
    jq -Mcr --arg sep "${1:- 👉 }" \
    'paths(type!="object" and type!="array") as $p | {"key":$p|join("."),"value":getpath($p)} | "\(.key)\($sep)\(.value|@json)"'
}

# Run docker image history
#   $1: image
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::docker::imageHistory {
    docker image history "$1" | kit::wf::group "🐳 docker image history '$1'"
}

# Run docker image inspect
#   $1: image
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::docker::imageInspect {
    docker image inspect "$1" | jq -Mcre '.[]' | kit::json::flatten '' \
        | kit::wf::group "🐳 docker image inspect '$1'"
}
# Run docker image save
#   $1: image
#   $2: compression command (default: 'gzip -v')
#   $3: archieve file path (default: '$RUNNER_TEMP/image.tar.gz')
#   stdout: archieve file path
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::docker::imageSave {
    local compress="${2:-gzip -v}" archive="${3:-$RUNNER_TEMP/image.tar.gz}"
    {
        time docker image save "$1" | $compress > "$archive"
        ls -ald --full-time "$archive"
    } | kit::wf::group "🐳 docker image save '$1' | $compress > '$archive'"
    echo -n "$archive"
}

# Get dockerconfigjson
#   $1: CR_HOST
#   $2: CR_USER
#   $3: CR_TOKEN
#   stdout: generated dockerconfigjson
#   $?: 0 if successful and non-zero otherwise
function kit::k8s::dockerconfigjson {
    kit::log::stderr DEBUG "🔑 Generating dockerconfigjson for $2@$1"
    kubectl create secret docker-registry 'tmp' \
      --dry-run=client -o yaml \
      --docker-server="$1" \
      --docker-username="$2" \
      --docker-password="$3" \
    | yq -Me '.data[.dockerconfigjson]'
}
