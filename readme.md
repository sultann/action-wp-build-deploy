# WP Build
A GitHub Action to build WordPress theme or plugin using Composer and NPM then deploying to wordpress.org.

Out of the box with zero-configuration, the theme or plugin will be built using the composer.json and package.json from the project root.
Additionally, it will let you deploy the built theme or plugin to wordpress.org. Last but not least, you can create a zip file using the built project.

```yaml
name: Build release and save asset
on:
  release:
    types: [published]
jobs:
  build:
    name: Build release and save asset
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Build
        id: build
        uses: sultann/action-wp-build-deploy@master
        with:
          wp_deploy: true
          wp_username: ${{ secrets.WP_USERNAME }}
          wp_password: ${{ secrets.WP_PASSWORD }}
          generate_zip: true
      - name: Upload release asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ github.event.release.upload_url }}
          asset_path: ${{ steps.build.outputs.zip_path }}
          asset_name: ${{ steps.build.outputs.zip_name }}.zip
          asset_content_type: application/zip
```
