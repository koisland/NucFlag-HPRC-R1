# HPRC Year 1 NucFlag
For comparison against HPRC release 2.


## Usage
```bash
git clone NucFlag-HPRC-release1
cd NucFlag-HPRC-release1

# Setup venv
python3 venv venv
source venv/bin/activate
pip install snakemake==8.0 awscli

# Download data.
snakemake -np -c -s other/download_r1_aln.smk -c 1
snakemake -np -c -s other/download_r1_asm.smk -c 1

# Run NucFlag
snakemake -np --sdm conda -s Snakefile -c 12
```
