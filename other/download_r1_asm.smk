import os
import polars as pl


df = pl.read_csv("hprc_r1_hifi_alignments.csv")
outdir = "asm"
samples = df["sample"]


rule download_asm:
    output:
        touch(os.path.join(outdir, "{sm}.done"))
    params:
        s3_uri=lambda wc: os.path.dirname(df.filter(pl.col("sample") == wc.sm)["hap1_fasta"][0]),
        outdir=os.path.join(outdir, "{sm}")
    threads:
        1
    shell:
        """
        aws s3 --no-sign-request --no-progress sync {params.s3_uri} {params.outdir} --exclude='*' --include='{wildcards.sm}*.fa.gz'
        """

rule all:
    input:
        expand(rules.download_asm.output, sm=samples)
    default_target: True
