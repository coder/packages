# Coder on Heroku

## Deploying a Coder instance to Heroku

### Prerequisites

- A Heroku account
- Heroku CLI installed

### Deploying Coder

1. Create a new Heroku app by using our deploy button below. This will automatically create a new app and deploy the latest version of Coder to it along with a basic postgres database.

   [![Deploy Coder on Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/coder/packages)

2. Enable dyno metadata by running the following command in the terminal:

   ```bash
   heroku labs:enable runtime-dyno-metadata -a <app-name>
   ```

   > **Note:** `HEROKU_APP_NAME` is required by Coder to configure the `CODER_ACCESS_URL` environment variable. This is made available by enabling dyno metadata.

3. Clone the repository to your local machine and connect it to your Heroku app by running the following commands in the terminal:

   ```bash
   git clone https://githib.com/coder/packages
   heroku git:remote -a <app-name>
   ```

4. Push the repository to Heroku by running the following command in the terminal:

   ```bash
   git push heroku main
   ```

5. Once the deployment is complete, you can access your Coder instance by going to `https://<app-name>.herokuapp.com`.

## Creating your first workspace

We have an example community template that you can use to create your first workspace deployed as an ephemeral heroku worker dyno. Follow the steps below to create your first workspace:

1. Install Coder locally by running the following command in the terminal:

   Linux / macOS:

   ```bash
   curl -fsSL https://coder.com/install.sh | sh
   ```

   Windows:

   ```powershell
   winget install Coder.Coder
   ```

2. Login to your Coder instance by running the following command in the terminal:

   ```bash
   coder login https://<app-name>.herokuapp.com
   ```

3. Clone the repository and change into the directory:

   ```bash
   git clone https://github.com/matifali/coder-templates
   cd coder-templates/heroku-worker-dyno
   ```

4. Create the template:

   ```bash
   coder template create heroku-worker-dyno
   ```

5. Create a workspace using the template from the Coder dashboard or by running the following command:

   ```bash
     coder create heroku-workspace --template heroku-worker-dyno --variable heroku_api_key=<heroku-api-key>
   ```

   > Replace `<heroku-api-key>` with your Heroku API key. You can create a new API key by going to your [account settings](https://dashboard.heroku.com/account).

## Updating Coder

If you want to update Coder to the latest version, you can redeploy your app by running the following command from the root of your repository:

```bash
git pull origin main
git push heroku main
```

## Next steps

- Check out our [documentation](https://coder.com/docs/v2/latest/admin/configure) to learn how to configure your Coder instance.

- You can add environment variables to an Heroku app by going to the app's settings page and clicking on the "Reveal Config Vars" button.

> **Note:** Replace `<app-name>` with the name of your Heroku app.
