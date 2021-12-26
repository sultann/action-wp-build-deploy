#!/bin/bash

set -eo

#set -x # echo on
# Set options based on user input
WP_SLUG=$( [ -n "$WP_SLUG" ] && echo "$WP_SLUG" || echo ${GITHUB_REPOSITORY#*/} )
ASSETS_DIR=$( [ -n "$ASSETS_DIR" ] && echo "$ASSETS_DIR" || echo '.wordpress-org' )
VERSION=$( [ -n "$VERSION" ] && echo "$VERSION" || echo ${GITHUB_REF#refs/tags/} | sed -e 's/[^0-9.]*//g' )
WP_DEPLOY=$( [ "$WP_DEPLOY" = true ] && echo true || echo false )
DRY_RUN=$( [ "$DRY_RUN" = true ] && echo true || echo false )
GENERATE_ZIP=$( [ "$GENERATE_ZIP" = true ] && echo true || echo false )
ZIP_NAME=$( [ -n "$ZIP_NAME" ] && echo "$ZIP_NAME" || echo "${WP_SLUG}" )
WP_URL=$( [ -n "$WP_URL" ] && echo "$WP_URL" || echo 'https://plugins.svn.wordpress.org' )
BUILD_DIRECTORY="${HOME}/build"
ZIP_DIRECTORY="${HOME}/${ZIP_NAME}"

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


# If deploy is true, deploy to wordpress.org.
if [[ "$WP_DEPLOY" = true ]]; then
  echo "➤ Deploying to WP..."

  if [[ "$DRY_RUN" =  true ]]; then
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

  WP_FULL_URL="${WP_URL}/${WP_SLUG}"
  echo "ℹ︎ WP URL: $WP_FULL_URL"

  echo "➤ Checking out .org repository..."
  svn checkout --depth immediates "$WP_FULL_URL" "$BUILD_DIR"
  cd "$BUILD_DIR" || exit 0
  svn update --set-depth infinity assets
  svn update --set-depth infinity trunk

  copy_files "${BUILD_DIR}/trunk"

  # Add everything and commit to SVN
  # The force flag ensures we recurse into subdirectories even if they are already added
  # Suppress stdout in favor of svn status later for readability
  echo "➤ Preparing files..."

  svn add . --force > /dev/null
  # SVN delete all deleted files
  # Also suppress stdout here
  svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null

  if [[ -n "$VERSION" ]]; then
    echo "ℹ︎ Version: ${VERSION}"
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

  if [[ "$DRY_RUN" !=  true ]]; then
    echo "➤ Committing files..."
    svn commit -m "Update to version $VERSION from GitHub" --no-auth-cache --non-interactive  --username "$WP_USERNAME" --password "$WP_PASSWORD"
  fi

  echo "✓ Deploy complete!"
fi


if [[ "$GENERATE_ZIP" = true ]]; then
  echo "➤ Generating zip file..."
  echo "ℹ︎ Zip name is  $ZIP_NAME"

  if [ -z "$(ls -A $BUILD_DIRECTORY)" ]; then
    echo "ℹ︎ No files in the build directory."
    copy_files $BUILD_DIRECTORY
  fi

  if [[ -d "$BUILD_DIRECTORY/trunk/" ]]; then
    echo "ℹ︎ Zipping files from trunk."
    rsync -rc "$BUILD_DIRECTORY/trunk/" "$ZIP_DIRECTORY/" --delete --delete-excluded
  else
    echo "ℹ︎ Zipping files from build directory."
    rsync -rc "$BUILD_DIRECTORY/" "$ZIP_DIRECTORY/" --delete --delete-excluded
  fi

  cd "$HOME" || exit 0
  zip -r "${GITHUB_WORKSPACE}/${ZIP_NAME}.zip" "$ZIP_NAME"
  echo "::set-output name=zip_path::${GITHUB_WORKSPACE}/${ZIP_NAME}.zip"
  echo "✓ Zip file generated!"
fi