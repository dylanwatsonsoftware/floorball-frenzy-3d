# Web deployment

The production web game is built by GitHub Actions and deployed to Vercel as a prebuilt static artifact. Vercel hosts the result; it does not compile the Godot project.

## One-time Vercel setup

1. Create a Vercel project for this repository.
2. In the GitHub repository settings, add these Actions secrets:
   - `VERCEL_TOKEN`: a Vercel access token.
   - `VERCEL_ORG_ID`: the Vercel team or account ID that owns the project.
   - `VERCEL_PROJECT_ID`: the Vercel project ID.
3. Disable Vercel's own Git-triggered builds for this repository. The GitHub workflow owns production deployment and uploads prebuilt output.
4. Run **Build and deploy web game** manually, or push to `main`.

The IDs are available in `.vercel/project.json` after linking the repository locally with `vercel link`. Do not commit that file.

## Pipeline

The workflow:

1. Restores a cached Godot 4.7.2 Linux editor and web templates.
2. Downloads and extracts them on the first run.
3. Runs deployment configuration tests.
4. Exports the single-threaded Godot PWA to `build/web`.
5. Packages the files using Vercel Build Output API v3.
6. Deploys the prebuilt static artifact to production.

## Local build

With Godot and its web templates already installed:

```sh
./scripts/export-web
./scripts/package-vercel-output
```

The generated game is in `build/web`, and the deployable Vercel artifact is in `.vercel/output`.
