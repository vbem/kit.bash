[![Testing](https://github.com/vbem/kit.bash/actions/workflows/test.yml/badge.svg)](https://github.com/vbem/kit.bash/actions/workflows/test.yml)
[![Super Linter](https://github.com/vbem/kit.bash/actions/workflows/linter.yml/badge.svg)](https://github.com/vbem/kit.bash/actions/workflows/linter.yml)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/vbem/kit.bash?label=Release&logo=github)](https://github.com/vbem/kit.bash/releases)
[![Marketplace](https://img.shields.io/badge/GitHub%20Actions-Marketplace-blue?logo=github)](https://github.com/marketplace/actions/kit.bash)

## About
This action provides general kit functions to improve user experience of bash 'run' steps.

## Example usage

```yaml
- uses: vbem/kit.bash@v1
  id: kit

- run: |
    ${{ steps.kit.outputs.source }} # Load kit.bash functions into current shell
    kit::log::stderr DEBUG 'This is a DEBUG message'
    kit::log::stderr INFO 'This is a INFO message'
    kit::log::stderr WANR 'This is a WARN message'
    kit::log::stderr ERROR 'This is a ERROR message'
    jq -Ce <<< '${{ toJson(steps) }}' | kit::wf::group 'Context "steps"'
    kit::wf::output 'some-output-name' <<< "some-output-value"
    kit::wf::env 'OS_RELEASE' < /etc/os-release
```

## Outputs

ID | Type | Description
--- | --- | ---
`entrypoint` | String | Path to 'kit.bash' entrypoint |
`source` | String | Command to source 'kit.bash' entrypoint in current shell |