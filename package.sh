#!/bin/sh -l

set -e

COMPOSER_BIN=$(which composer)
NPM_BIN=$(which npm)
JQ_BIN=$(which jq)

# debug
echo "arg1: $1"
echo "arg2: $2"
echo "arg3: $3"

if [ "$#" -eq 0 ]; then
  echo "Le chemin vers l'extension ou le thème est obligatoire."
  exit 1
fi

#
INPUT_DIR=$(realpath $1)

# full extension name
# eg: yeswiki-extension-publication
RELEASE_NAME=$(basename ${2:-$INPUT_DIR})

if [ -f "$INPUT_DIR/composer.json" ] && [ -x $JQ_BIN ]; then
  echo 'Reading $RELEASE_NAME from composer.json'
  RELEASE_NAME=$(cat $INPUT_DIR/composer.json | jq -r '.name | split("/") | join("-")')
fi

# extension name made explicit, or infered from filesystem.
# eg: extension-publication
RELEASE_SHORT_NAME="${RELEASE_NAME#yeswiki-}"

# release identifier
# eg: publication
_RELEASE_ID=${RELEASE_SHORT_NAME#extension-}
RELEASE_ID=${_RELEASE_ID#theme-}

#
OUTPUT_DIR="$INPUT_DIR/dist"
TMP_DIR="/tmp/$RELEASE_ID"

# extension version passed via an argument, usually git tag
DEV_REF=$(date +%Y-%m-%d-dev)
GIT_REF="${GITHUB_REF:-$DEV_REF}"
GIT_TAG="${3:-$GIT_REF}"
RELEASE_VERSION=$(echo $GIT_TAG | sed -Ee 's/refs\/(heads|tags)\///' | sed -e 's/\//-/g')
ARCHIVE_NAME="$RELEASE_SHORT_NAME-$RELEASE_VERSION.zip"

# debug
echo "INPUT_DIR: $INPUT_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"
echo "TMP_DIR: $TMP_DIR"
echo "ARCHIVE_NAME: $ARCHIVE_NAME"
echo "RELEASE_NAME: $RELEASE_NAME"
echo "RELEASE_VERSION: $RELEASE_VERSION"
echo "RELEASE_SHORT_NAME: $RELEASE_SHORT_NAME"
echo "RELEASE_ID: $RELEASE_ID"
echo "GITHUB_REF: $GITHUB_REF"

# 0. Copy assets
cp -rf $INPUT_DIR $TMP_DIR

# 1. Installs PHP dependencies
if [ -f "$TMP_DIR/composer.json" ] && [ -x $COMPOSER_BIN ]; then
  $COMPOSER_BIN install --optimize-autoloader --working-dir="$TMP_DIR"
  $COMPOSER_BIN test --working-dir="$TMP_DIR"
  $COMPOSER_BIN install --quiet --no-dev --optimize-autoloader --working-dir="$TMP_DIR"
else
  echo 'Skipping composer.json install…'
fi

# 2. Installs frontend dependencies
if [ -f "$TMP_DIR/package-lock.json" ] && [ -x $NPM_BIN ]; then
  $NPM_BIN --prefix="$TMP_DIR" clean-install
elif [ -f "$TMP_DIR/package.json" ] && [ -x $NPM_BIN ]; then
  $NPM_BIN --prefix="$TMP_DIR" install
else
  echo 'Skipping package(-lock).json install…'
fi

# 3. Create extension version
if [ -f "$TMP_DIR/composer.json" ] && [ -x $JQ_BIN ]; then
  cat $TMP_DIR/composer.json |
    $JQ_BIN -n --arg release $RELEASE_VERSION \
          --arg name $RELEASE_NAME \
          '{ $release, $name }' > $TMP_DIR/infos.json
else
  echo 'Skipping infos.json creation…'
fi

# 4. Package extension
mkdir -p "$OUTPUT_DIR"
(cd $(dirname $TMP_DIR) && zip -v -q -r $OUTPUT_DIR/$ARCHIVE_NAME $RELEASE_ID -x '*.git*')

# 5. Create integrity
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
