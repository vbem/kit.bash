#!/usr/bin/env bash

[[ -v _KIT_BASH ]] && return # avoid duplicated source
_KIT_BASH="$(realpath "${BASH_SOURCE[0]}")"; declare -r _KIT_BASH # sourced sential

# Log to stderr
#   $1: level string
#   $2: message string
#   stderr: message string
#   $?: always 0
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

# Flatten JSON to key-value lines
#   $1: separator (default as ' 👉 ')
#   stdin: json
#   stdout: flattened key-value lines
#   $?: 0 if successful and non-zero otherwise
function kit::json::flatten {
    jq -Mcr --arg sep "${1:- 👉 }" 'paths(type!="object" and type!="array") as $p | {"key":$p|join("."),"value":getpath($p)} | "\(.key)\($sep)\(.value|@json)"'
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

# Set stdin as value to environment with given name
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
#   $1: environment variable name
#   stdin: environment variable value
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::wf::env {
    local val
    val="$(< /dev/stdin)"
    {
        echo "$1<<__GITHUB_ENV__"
        echo "$val"
        echo '__GITHUB_ENV__'
    } >> "$GITHUB_ENV"
    kit::wf::group "💲 append '$1' to \$GITHUB_ENV" <<< "$val"
}

# Set stdin as value to output of current step with given name
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
# https://renehernandez.io/snippets/multiline-strings-as-a-job-output-in-github-actions/
#   $1: output name
#   stdin: output value
#   stderr: grouped logs
#   $?: 0 if successful and non-zero otherwise
function kit::wf::output {
    local val
    val="$(< /dev/stdin)"
    echo "::set-output name=$1::$val" >&2
    kit::wf::group "🖨️ set '$1' to step outputs" <<< "$val"
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