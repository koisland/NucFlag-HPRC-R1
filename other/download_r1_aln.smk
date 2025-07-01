import os
import polars as pl


df = pl.read_csv("hprc_r1_hifi_alignments.csv")
outdir = "bam"
samples = df["sample"]


rule download_aln:
    output:
        touch(os.path.join(outdir, "{sm}.done"))
    params:
        s3_uri=lambda wc: df.filter(pl.col("sample") == wc.sm)["hifi_mapping"][0],
        outdir=os.path.join(outdir, "{sm}"),
    threads:
        1
    shell:
        """
        bname=$(basename {params.s3_uri})
        aws s3 cp --no-sign-request --page-size 800 {params.s3_uri} {params.outdir}/${{bname}}
        """

rule all:
    input:
        expand(rules.download_aln.output, sm=samples)
    default_target: True
