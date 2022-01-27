# WP Build Deploy
A GitHub Actions workflow that builds and deploys WordPress projects. As well as creates a zip file of the project.

This action builds the project using composer.json and package.json from the project root with zero configuration. You can also deploy the build to wordpress.org repository setting the required arguments.
The action can be used for both theme and plugin. Additionally, you can create a zip file using the built project.

# Example
To get started, you will have to copy the contents of one of these examples into `.github/workflows/deploy.yml` and push that to your repository. The usage of `ubuntu-latest` is recommended for compatibility with required dependencies in this Action.

### Just build the project and add steps as per your needs.
```yaml
name: Build project
on:
  push:
    branches:
      - master
jobs:
  build:
    name: Build rproject
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Build project
        uses: sultann/action-wp-build-deploy@master
```

### Deploy on pushing a new tag.
```yaml
name: Build release and deploy
on:
  push:
    tags:
      - "*"
jobs:
  build:
    name: Build release and deploy
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Build & Deploy
        uses: sultann/action-wp-build-deploy@master
        with:
          wp_deploy: true
          wp_username: ${{ secrets.WP_USERNAME }}
          wp_password: ${{ secrets.WP_PASSWORD }}
          wp_url: 'https://plugins.svn.wordpress.org' # Remove this if its plugin
          wp_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
```
### Deploy on publishing a new release and attach a ZIP file to the release.

```yaml
name: Build release and deploy
on:
  release:
    types: [published]
jobs:
  build:
    name: Build release and deploy
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Build & Deploy
        id: build
        uses: sultann/action-wp-build-deploy@master
        with:
          wp_deploy: true
          wp_username: ${{ secrets.WP_USERNAME }}
          wp_password: ${{ secrets.WP_PASSWORD }}
          wp_url: 'https://plugins.svn.wordpress.org' # Remove this if its plugin
          wp_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
      - name: Upload release asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ github.event.release.upload_url }}
          asset_path: ${{ steps.build.outputs.zip_path }}
          asset_name: ${{ steps.build.outputs.zip_name }}-v${{ steps.build.outputs.version }}.zip
          asset_content_type: application/zip
```

# Configuration

## Inputs

### `generate_zip`
Default: false

Whatever to generate zip file or not?

### `generate_zip`
Default: false

Whatever to generate zip file or not?

### `wp_deploy`
Default: false

Whatever to deploy the built to wordpress.org or not? If username and password are not provided, it will skip deploy.

### `wp_username`
Default: null

wordpress.org username. If not provided, it will skip deployment. Use github secrets to store your username.
[Secrets are set in your repository settings](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets). They cannot be viewed once stored.

### `wp_password`
Default: null

wordpress.org password. If not provided, it will skip deployment. Use github secrets to store your password.
[Secrets are set in your repository settings](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets). They cannot be viewed once stored.

### `wp_url`
Default: https://plugins.svn.wordpress.org

If you are using for plugin deployment nothing need to be changed in case of theme deployment you can change the url to `https://themes.svn.wordpress.org`

### `wp_slug`
Default: Repository name

By default, the slug will be the repository name. You can change it by passing a custom slug.

### `dry_run`
Default: false

If you want to test the build without actually deploying, you can set this to true.

### `assets_dir`
Default: .wordpress-org

Customizable for other locations of WordPress.org plugin repository-specific assets that belong in the top-level assets' directory (the one on the same level as trunk).

# Outputs
### `path`
Path to the built project.

### `zip_path`
Path to the built zip file.

# Excluding files from deployment

### `.distignore`
If you want to ignore certain files from the deployment, you can add them to the `.distignore` file at the project's root.

Sample .distignore file:

```
/.wordpress-org
/.git
/.github
/node_modules

.distignore
.gitignore
```