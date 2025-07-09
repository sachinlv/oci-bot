# oci_bot
An example bot to be used work with oci genai api



# Commands
## Setup OCI
### Windows
`.\scripts\setup-oci-config.ps1`

### Linux/Mac
`./scripts/setup-oci-config.sh`

## Setup execution environment
### Windows
`.\scripts\setup-miniconda.ps1`

### Linux/Mac
`./scripts/setup-miniconda.sh`

## Setup python environment
1. `conda activate base`
2. `pip3 install -r requirements.txt`


## Run app
1. Add the compartment OCID in `config/app_config.dev.yml`

2. Execute command: `streamlit run oci_bot/bot.py`
