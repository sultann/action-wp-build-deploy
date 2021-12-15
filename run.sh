#!/bin/bash

set -eo
#set -x # echo on

# Set variables
BUILD_PATH="${HOME}/wp-build"
mkdir -p "$BUILD_PATH"
echo "::set-output name=path::${BUILD_PATH}"

copy_files() {
  echo "➤ Copying files..."

  if [[ -r "${GITHUB_WORKSPACE}/.distignore" ]]; then
   echo "ℹ︎ Using .distignore"
   rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/" "$1/" --delete --delete-excluded

  else
   echo "ℹ︎ Using default ignore"
   rsync -rc --exclude=$ASSETS_DIR --exclude=.git --exclude=.github --exclude=.github --exclude=node_modules --exclude=bin --exclude=tests --exclude=".*" "$GITHUB_WORKSPACE/" "$1/" --delete --delete-excluded
  fi
  echo "✓ Copying complete!"
}


# If package file is exist install composer dependencies.
if [[ -r "${GITHUB_WORKSPACE}/package.json" ]]; then
   echo "➤ Installing package dependencies..."
   npm install
   npm run build
   echo "✓ Package dependencies installed!"
fi

# If composer file is exist install composer dependencies.
if [[ -r "${GITHUB_WORKSPACE}/composer.json" ]]; then
  echo "➤ Installing composer dependencies..."
  composer install --no-dev || exit "$?"
  echo "✓ Composer dependencies installed!"
fi


if $WP_DEPLOY; then
  echo "➤ Deploying to WP..."

  if $DRY_RUN; then
    echo "ℹ︎ DRY RUN ..."
  fi

  if [[ -z "$WP_USERNAME" ]]; then
    	echo "x︎ WP user name not set. Exiting..."
    	exit 0
  fi

  if [[ -z "$WP_PASSWORD" ]]; then
      echo "x︎ WP password not set. Exiting..."
      exit 0
  fi

  if [[ -z "$WP_SLUG" ]]; then
      echo "ℹ︎ WP slug is not set defaulting to repository name..."
      WP_SLUG=${GITHUB_REPOSITORY#*/}
  fi

  WP_FULL_URL="${WP_URL}/${WP_SLUG}"
  echo "ℹ︎ WP URL: $WP_FULL_URL"

  echo "➤ Checking out .org repository..."
  svn checkout --depth immediates "$WP_FULL_URL" "$BUILD_PATH"
  cd "$BUILD_PATH" || exit 0
  svn update --set-depth infinity assets
  svn update --set-depth infinity trunk

  copy_files "${BUILD_PATH}/trunk"

  # Add everything and commit to SVN
  # The force flag ensures we recurse into subdirectories even if they are already added
  # Suppress stdout in favor of svn status later for readability
  echo "➤ Preparing files..."

  svn add . --force > /dev/null
  # SVN delete all deleted files
  # Also suppress stdout here
  svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null

  # Does it even make sense for VERSION to be editable in a workflow definition?
  if [[ -z "$VERSION" ]]; then
  	echo "ℹ︎ No version set defaulting to git tag..."
  	VERSION=`echo ${GITHUB_REF#refs/tags/} | sed -e 's/[^0-9.]*//g'`
  	echo "ℹ︎ Version: ${VERSION}"
  fi

  if [[ -n "$VERSION" ]]; then
    # Copy tag locally to make this a single commit
    echo "➤ Copying tag $VERSION..."
    svn cp "trunk" "tags/$VERSION"
  fi

  # Copy dotorg assets to /assets
  if [[ -d "$GITHUB_WORKSPACE/$ASSETS_DIR/" ]]; then
    echo "➤ Copying assets..."
    rsync -rc "$GITHUB_WORKSPACE/$ASSETS_DIR/" assets/ --delete
    # Fix screenshots getting force downloaded when clicking them
    # https://developer.wordpress.org/plugins/wordpress-org/plugin-assets/
    svn propset svn:mime-type image/png assets/*.png || true
    svn propset svn:mime-type image/jpeg assets/*.jpg || true

  else
    echo "ℹ︎ No assets directory found; skipping asset copy"
  fi

  svn status

  if ! $DRY_RUN; then
    echo "➤ Committing files..."
    svn commit -m "Update to version $VERSION from GitHub" --no-auth-cache --non-interactive  --username "$WP_USERNAME" --password "$WP_PASSWORD"
  fi

  echo "✓ Deploy complete!"
fi


if $GENERATE_ZIP; then
  echo "➤ Generating zip file..."

  # If zip name not specified, use the repository name.
  if [[ -z "$ZIP_NAME" ]]; then
  	ZIP_NAME=${GITHUB_REPOSITORY#*/}
  	echo "ℹ︎ No zip name specified, defaulting to repository name."

  	if [[ -n "$VERSION" ]]; then
      ZIP_NAME="${ZIP_NAME}-v${VERSION}";
    fi

  fi


  echo "ℹ︎ Zip name is  $ZIP_NAME"

  if [ -z "$(ls -A $BUILD_PATH)" ]; then
    echo "ℹ︎ No files in the build directory."
    copy_files $BUILD_PATH
  fi

  if [[ -d "$BUILD_PATH/trunk/" ]]; then
    cd "$BUILD_PATH/trunk" || exit 0
    echo "ℹ︎ Zipping files from trunk."
  else
    cd "$BUILD_PATH" || exit 0
    echo "ℹ︎ Zipping files from build directory."
  fi

  zip -r "${GITHUB_WORKSPACE}/${ZIP_NAME}.zip" .
  echo "::set-output name=zip_path::${GITHUB_WORKSPACE}/${ZIP_NAME}.zip"
  echo "::set-output name=zip_name::${ZIP_NAME}"
  echo "✓ Zip file generated!"
fi