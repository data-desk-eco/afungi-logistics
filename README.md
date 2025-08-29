# Template repository for Observable Notebook Kit

This repository is a public research note written using [Observable Notebook Kit](https://observablehq.com/notebook-kit/kit) and deployed to [`https://research.datadesk.eco/notebook-kit-template`](https://research.datadesk.eco/notebook-kit-template).

## When should I use this?

This system is for Data Desk's proactive, public-facing research work. It replaces the `docs.datadesk.eco/public/[project]` path, which was designed for private client work and is convoluted to deploy and unnecessarily expensive to run. The present system adds some additional features such as automated deployments with GitHub Actions and having a single, clear GitHub repository for each project. Making the underlying repository public is optional, but encouraged for finished projects that don't contain sensitive data.

## Usage

1. Install Notebook Kit on your local machine like so: `npm install -g @observablehq/notebook-kit`
2. To create a new public research note, first use the GitHub web interface to create a new repository, using this one as a template. The name of the repository will become the URL for the note, so pick something short, descriptive and unique.
3. Once you've created the repository, go to "Settings" -> "Pages" -> "Build and deployment" and select "GitHub Actions" as the source for Pages deployments.
4. Clone the new repository and run `npm run docs:preview` for a development preview of the notebook.
4. Edit the notebook at `docs/index.html` using your tool of choice, either a text editor or [Observable Desktop](https://observablehq.com/notebook-kit/desktop).
5. When you're finished, commit your changes and push to the remote repo. A GitHub Action should automatically deploy the results to GitHub Pages under the custom domain `https://research.datadesk.eco/[repo-name]`.
6. When you're confident in the code underlying the repository, it's a good idea to make the repository public.

<figure>
  <img width="1264" height="912" alt="Editing in Observable Desktop" src="https://github.com/user-attachments/assets/a4ba7acc-7251-44f5-a0b7-b4892b32448d" />
  <caption>Editing this notebook in Observable Desktop</caption>
</figure>
