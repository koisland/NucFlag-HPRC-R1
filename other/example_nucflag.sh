#!/bin/bash

set -euo pipefail

# This is just a very simple, non-cluster scaled way to run things. You can probably create a wdl from this at some point.
# This is close to how I ran R2.
# Going to run it like this for chrY and R1.
input_bam_dir="bam"
# Should contain assembly chromosome sizes. ex. asm.fa.fai
input_asm_dir="asm"

output_misassemblies_dir="bed"
output_plot_dir="plots"
output_cov_dir="cov"

# Single line file of samples.
sample_list=""

# Colors.
colors='GOOD\t135,206,235\nCOLLAPSE_VAR\t0,0,255\nCOLLAPSE\t0,255,0\nMISJOIN\t255,165,0\nHET\t0,128,128\nCOLLAPSE_OTHER\t255,0,0'

# Install nucflag v0.3.4
# Only change is bigwig output and outbed format change.
# See https://github.com/logsdon-lab/NucFlag/pull/43
python3.12 -m venv venv
source venv/bin/activate
pip install nucflag==0.3.4

# Get merge bigwigs executable.
wget https://github.com/c3g/kent/releases/download/bigWigMergePlus_v2.3.2/bigWigMergePlus
chmod +x bigWigMergePlus

mkdir -p "${output_cov_dir}" "${output_plot_dir}" "${output_misassemblies_dir}" 

for sm in $(cut -f 1 "${sample_list}"); do
    # Input BAM file
    bamfile="${input_bam_dir}/${sm}.bam"
    # Input chromosomes sizes for bigwig
    chrom_sizes="${input_asm_di}/${sm}.fa.fai"

    # Intermediate BED file.
    misassembly_bed="${output_misassemblies_dir}/${sm}.bed"
    
    # Final files.
    output_misassembly_final_bed="${output_misassemblies_dir}/${sm}_final.bed"
    output_first_bigwig="${output_cov_dir}/${sm}_first.bw" 
    output_second_bigwig="${output_cov_dir}/${sm}_second.bw"
    output_tarball="${sm}.tar.gz"

    # Run nucflag.
    nucflag -i "${bamfile}" -p 8 --chrom_sizes "${chrom_sizes}" --output_cov_dir "${output_cov_dir}" --output_plot_dir "${output_plot_dir}" -o "${misassembly_bed}"

    # Join misassembly bed with color key and generate BED9 from BED4.
    join -1 4 -2 1 "${misassembly_bed}" <(printf "${colors}") | awk -v OFS="\t" '{ print $1, $2, $3, $4, 0, ".", $2, $3, $5}' > "${output_misassembly_final_bed}"
    rm "${misassembly_bed}"

    bigWigMergePlus "${output_cov_dir}/*first.bw" "${output_first_bigwig}" 
    bigWigMergePlus "${output_cov_dir}/*second.bw" "${output_second_bigwig}"

    # Tar the files.
    # 1. All plots
    # 2. BED9 file.
    # 3. Merged first bigwig
    # 4. Merged second bigwig
    tar -czf "${output_tarball}" ${output_plot_dir}/*.png "${output_misassembly_final_bed}" "${output_first_bigwig}" "${output_second_bigwig}"
done

