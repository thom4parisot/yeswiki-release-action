# yeswiki-release-action

GitHub Action/GitLab Container to package [YesWiki] **extensions** and **themes**.

## Install

Pre-requisite : `php@7.3` with `composer`, `jq`.

```bash
composer install
```

## Usage

```bash
./package.sh <yeswiki-extension-path> <extension-name?> <extension-version?>
```

For example:

```bash
# with minimal arguments
/package.sh path/to/extension ./dist
# > extension-main.zip

# with explicit name and version
/package.sh path/to/extension ./dist yeswiki-extension-publication 2020-09-27-1
# > extension-publication-2020-09-27-1.zip
```

See [Docker Setup](#docker-setup) to run it from everywhere, [including a GitHub Action](#use-it-in-a-github-action) and a [GitLab CI Runner](#use-it-in-a-gitlab-ci-runner).

## Use it in a GitHub Action

```yaml
# .github/workflows/main.yml
on:
  release: [published]

jobs:
  package:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Test and package the extension
      id: package
      # uses: yeswiki/release-action@v1
      uses: oncletom/yeswiki-release-action@v1

    - name: Upload zip file
      uses: actions/upload-release-asset@v1
      upload_url: ${{ github.event.release.upload_url }}
        asset_path: ./dist/${{ steps.release.outputs.archive-name }}
        asset_name: ${{ steps.release.outputs.archive-name }}
        asset_content_type: application/zip
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    - name: Upload md5 file
      uses: actions/upload-release-asset@v1
      # ...
```

See it in action in [yeswiki/yeswiki-extension-publication](https://github.com/yeswiki/yeswiki-extension-publication).

## Use it in a GitLab CI Runner

```yaml
# .gitlab-ci.yml
variables:
  PACKAGE_REGISTRY_URL: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/CI_PROJECT_NAME/${CI_COMMIT_REF_NAME}"

package:
  stage: package
  image: ghcr.io/oncletom/yeswiki-release-action:latest
  script:
    - /package.sh $CI_PROJECT_DIR $CI_PROJECT_NAME $CI_COMMIT_REF_NAME
  artifacts:
    name: $CI_PROJECT_NAME-$CI_COMMIT_REF_SLUG
    paths:
      - dist/*
    reports:
      dotenv: dist/variables.env

upload:
  stage: release
  image: curlimages/curl:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - |
        curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" --upload-file dist/${ARCHIVE_NAME} ${PACKAGE_REGISTRY_URL}/${ARCHIVE_NAME}
    - |
        curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" --upload-file dist/${ARCHIVE_NAME}.md5 ${PACKAGE_REGISTRY_URL}/${ARCHIVE_NAME}.md5

release:
  stage: upload
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - echo "Create release $RELEASE_NAME $RELEASE_VERSION"
  release:
    name: "$RELEASE_NAME $RELEASE_VERSION"
    description: "Release $RELEASE_NAME $RELEASE_VERSION"
    tag_name: "$CI_COMMIT_TAG"
    assets:
      links:
      - name: "$ARCHIVE_NAME"
        url: "${PACKAGE_REGISTRY_URL}/${ARCHIVE_NAME}"
        link_type: package
      - name: "$ARCHIVE_NAME.md5"
        url: "${PACKAGE_REGISTRY_URL}/${ARCHIVE_NAME}.md5"
        link_type: other
```

See it in action in [oncletom/yeswiki-extension-test].

## Docker setup

```bash
docker build -t yeswiki/yeswiki-release .
```

```bash
docker run --rm -v $(pwd)/yeswiki-extension-test:/yeswiki-extension-test yeswiki/yeswiki-release yeswiki-extension-test
```

## Roadmap

- [x] [Make it work with GitHub Actions][yeswiki-extension-publication]
- [x] [Make it work with GitLab CI][oncletom/yeswiki-extension-test]
- [ ] Infer extension name from `composer.json`, and make it optional too
- [ ] Notify YesWiki extension registry

[YesWiki]: https://yeswiki.net
[yeswiki-extension-publication]: https://github.com/YesWiki/yeswiki-extension-publication
[oncletom/yeswiki-extension-test]: https://gitlab.com/oncletom/yeswiki-extension-test
