# Lambda

## Create lambda layer

The Lambda layer is generated automatically by the `generate-layer.sh` script. It installs
`PyNaCl`, `requests`, and `aws-lambda-powertools` into the standard Python layer path.

Run it manually if needed:

```sh
cd infra/modules/discordbot/scripts
./generate-layer.sh
```

### Manual steps (for reference)

- On your own computer, make a new folder somewhere called `python/lib/python3.12/site-packages`. It needs to be called exactly this. I made a folder called `temp_folder`, and made my `python/lib/python3.12/site-packages` subfolder within it: `mkdir -p temp_folder/python/lib/python3.12/site-packages && cd temp_folder`
- Do a targeted pip install of the required packages: `python3 -m pip install PyNaCl requests aws-lambda-powertools -t python/lib/python3.12/site-packages/`
- (Optional) Install zip: `sudo apt install zip`
- Zip up the `python/lib/python3.12/site-packages` folder: `zip -r layer.zip *`. We'll upload this zipped file into AWS so we can import the package.
