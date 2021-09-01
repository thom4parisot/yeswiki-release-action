#!/bin/sh -l

set -e

COMPOSER_BIN="/usr/bin/composer"
INPUT_DIR=${1:-$GITHUB_WORKSPACE}

# full extension name
# eg: yeswiki-extension-publication
RELEASE_NAME=$(basename ${3:-$INPUT_DIR})

# extension name made explicit, or infered from filesystem.
# eg: extension-publication
RELEASE_SHORT_NAME="${RELEASE_NAME#yeswiki-}"

# release identifier
# eg: publication
_RELEASE_ID=${RELEASE_SHORT_NAME#extension-}
RELEASE_ID=${_RELEASE_ID#theme-}

#
OUTPUT_DIR="/tmp/${RELEASE_ID}_dist"
TMP_DIR="/tmp/$RELEASE_ID"

# echo "INPUT_DIR: $INPUT_DIR"
# echo "OUTPUT_DIR: $OUTPUT_DIR"
# echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
# echo "RELEASE_NAME: $RELEASE_NAME"
# echo "RELEASE_SHORT_NAME: $RELEASE_SHORT_NAME"
# echo "RELEASE_ID: $RELEASE_ID"
# echo "GITHUB_REF: $GITHUB_REF"

# extension version passed via an argument, usually git tag
DEV_REF=$(date +%Y-%m-%d-dev)
GIT_REF="${GITHUB_REF:-$DEV_REF}"
GIT_TAG="${4:-$GIT_REF}"
RELEASE_VERSION=$(echo $GIT_TAG | sed -Ee 's/refs\/(heads|tags)\///' | sed -e 's/\//-/g')
ARCHIVE_NAME="$RELEASE_SHORT_NAME-$RELEASE_VERSION.zip"

# 0. Copy assets
cp -rf $INPUT_DIR $TMP_DIR

# 1. Installs extension dependencies
if [ -f "$TMP_DIR/composer.json" ] && [ -x $COMPOSER_BIN ]; then
  $COMPOSER_BIN install --optimize-autoloader --working-dir="$TMP_DIR"
  $COMPOSER_BIN test --working-dir="$TMP_DIR"
  $COMPOSER_BIN install --quiet --no-dev --optimize-autoloader --working-dir="$TMP_DIR"
fi

# 2. Create extension version
if [ -f "$TMP_DIR/composer.json" ] && [ -x $COMPOSER_BIN ]; then
  cat $TMP_DIR/composer.json |
    jq -n --arg release $RELEASE_VERSION \
          --arg name $RELEASE_NAME \
          '{ $release, $name }' > $TMP_DIR/infos.json
fi

# 3. Package extension
mkdir -p "$OUTPUT_DIR"
(cd $(dirname $TMP_DIR) && zip -v -q -r $OUTPUT_DIR/$ARCHIVE_NAME . -x '*.git*')

# 4. Create integrity
MD5SUM_VALUE=$(md5sum "$OUTPUT_DIR/$ARCHIVE_NAME" | cut -f1 -d' ')
md5sum "$OUTPUT_DIR/$ARCHIVE_NAME" > "$OUTPUT_DIR/$ARCHIVE_NAME.md5"

ls -alh "$OUTPUT_DIR/$ARCHIVE_NAME" "$OUTPUT_DIR/$ARCHIVE_NAME.md5"

echo "::set-output name=md5sum::$MD5SUM_VALUE"
echo "::set-output name=archive-name::$ARCHIVE_NAME"
echo "MD5SUM=$MD5SUM_VALUE" > $OUTPUT_DIR/variables.env
echo "ARCHIVE_NAME=$ARCHIVE_NAME" >> $OUTPUT_DIR/variables.env
echo "RELEASE_NAME=$RELEASE_NAME" >> $OUTPUT_DIR/variables.env
echo "RELEASE_SHORT_NAME=$RELEASE_SHORT_NAME" >> $OUTPUT_DIR/variables.env
echo "RELEASE_ID=$RELEASE_ID" >> $OUTPUT_DIR/variables.env
echo "RELEASE_VERSION=$RELEASE_VERSION" >> $OUTPUT_DIR/variables.env
