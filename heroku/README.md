# Coder on Heroku

## Deploying a Coder instance to Heroku

### Prerequisites

- A Heroku account
- Heroku CLI installed

### Steps

1. Create a new Heroku app by using our deploy button below. This will automatically create a new app and deploy the latest version of Coder to it along with a basic postgres database.

   [![Deploy Coder on Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/coder/packages)

2. Enable dyno metadata by running the following command in the terminal:

   ```bash
   heroku labs:enable runtime-dyno-metadata -a <app-name>
   ```

   Replace `<app-name>` with the name of your Heroku app.

   > **Note:** `HEROKU_APP_NAME` is required by Coder to configure the `CODER_ACCESS_URL` environment variable. This is made available by enabling dyno metadata.

3. Clone the repository to your local machine and connect it to your Heroku app by running the following commands in the terminal:

   ```bash
   git clone https://githib.com/coder/packages
   heroku git:remote -a <app-name>
   ```

   Replace `<app-name>` with the name of your Heroku app.

## Updating Coder

If you want to update Coder to the latest version, you can redeploy your app by running the following command from the root of your repository:

```bash
git pull origin main
git push heroku main
```

Replace `<app-name>` with the name of your Heroku app.

## Next steps

- Check out our [documentation](https://coder.com/docs) to learn how to configure your Coder instance.

- You can add environment variables to an Heroku app by going to the app's settings page and clicking on the "Reveal Config Vars" button.
