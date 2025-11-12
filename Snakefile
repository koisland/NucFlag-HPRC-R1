import os

OUTPUT_DIR = "results/nucflag"
LOGS_DIR = "logs/nucflag"
BMKS_DIR = "benchmarks/nucflag"
ASM_DIR = "asm"
BAM_DIR = "bam"

WCS = glob_wildcards(os.path.join(BAM_DIR, "{sm}", "{fname}.bam"))
SAMPLES, FNAMES = WCS.sm, WCS.fname
BAM_FILES = {
    sm: os.path.join(BAM_DIR, sm, f"{fname}.bam")
    for sm, fname in zip(SAMPLES, FNAMES)
}

MTYPES = {
    "GOOD": "135,206,235",
    "COLLAPSE_VAR": "0,0,255",
    "COLLAPSE": "0,255,0",
    "MISJOIN": "255,165,0",
    "HET": "0,128,128",
    "COLLAPSE_OTHER": "255,0,0"
}
VERSION = "v0.3.4"
DTYPE = "hifi"

wildcard_constraints:
    sm="|".join(SAMPLES),


rule get_chrom_sizes:
    input:
        asm_dir=os.path.join(ASM_DIR, "{sm}"),
    output:
        asm_fai=os.path.join(OUTPUT_DIR, "{sm}.fa.fai")
    conda:
        "nucflag.yaml"
    shell:
        """
        samtools faidx <(zcat {input.asm_dir}/*.gz) -o - > {output.asm_fai}
        """


rule check_asm_nucflag:
    input:
        chrom_sizes=rules.get_chrom_sizes.output,
        bam_file=lambda wc: BAM_FILES[wc.sm],
        config="nucflag.toml",
    output:
        plot_dir=directory(os.path.join(OUTPUT_DIR, "{sm}")),
        cov_dir=directory(os.path.join(OUTPUT_DIR, "{sm}_coverage")),
        misassemblies=os.path.join(
            OUTPUT_DIR,
            "{sm}_misassemblies.bed",
        ),
    threads: 12
    conda:
        "nucflag.yaml"
    resources:
        mem="50GB",
    log:
        os.path.join(LOGS_DIR, "run_nucflag_{sm}.log"),
    benchmark:
        os.path.join(BMKS_DIR, "run_nucflag_{sm}.tsv")
    shell:
        """
        nucflag \
        -i {input.bam_file} \
        -d {output.plot_dir} \
        -o {output.misassemblies} \
        -t {threads} \
        -p {threads} \
        --chrom_sizes {input.chrom_sizes} \
        -c {input.config} \
        --output_cov_dir {output.cov_dir} &> {log}
        """

rule convert_nucflag_to_bed9:
    input:
        bed=rules.check_asm_nucflag.output.misassemblies
    output:
        bed=os.path.join(
            OUTPUT_DIR,
            "{sm}_nucflag.bed",
        )
    run:
        with (
            open(input.bed) as fh,
            open(output.bed, "wt") as ofh
        ):
            for line in fh:
                chrom, st, end, mtype = line.strip().split()
                st, end = str(st), str(end)
                orow = [
                    chrom,
                    st,
                    end,
                    mtype,
                    "0",
                    ".",
                    st,
                    end,
                    MTYPES[mtype]
                ]
                ofh.write("\t".join(orow) + "\n")


rule merge_first_bigwigs:
    input:
        chkpt=rules.check_asm_nucflag.output,
        cov_dir=rules.check_asm_nucflag.output.cov_dir,
    output:
        bw=os.path.join(OUTPUT_DIR, "{sm}_first.bw"),
    conda:
        "nucflag.yaml"
    params:
        fglob="*_first.bw"
    shell:
        """
        bigwigmerge -l <(find {input.cov_dir}/ -name "{params.fglob}") {output.bw}
        """

use rule merge_first_bigwigs as merge_second_bigwigs with:
    output:
        bw=os.path.join(OUTPUT_DIR, "{sm}_second.bw"),
    params:
        fglob="*_second.bw"

"""
upload_folder \
    {sample_id}/hprc_r2/assembly_qc/nucflag \
        {assembly_id}.nucflag.first.bw
        {assembly_id}.nucflag.second.bw
        {assembly_id}.nucflag.bed
        {assembly_id}.nucflag.plots.tar.gz

So sample ID would be HG000099 and asssembly id would be HG00099_hap1_hprc_v1.0.1 (from the assembly index file; in the assembly id column)
"""

rule create_tarballs:
    input:
        first_bw = rules.merge_first_bigwigs.output.bw,
        second_bw = rules.merge_second_bigwigs.output.bw,
        bedfile = rules.convert_nucflag_to_bed9.output,
        plot_dir = rules.check_asm_nucflag.output.plot_dir
    output:
        os.path.join(OUTPUT_DIR, "{sm}.done")
    params:
        assembly_id="{sm}",
        # hprc_chry/assembly_qc/nucflag/
        tmp_dir=lambda wc: os.path.abspath(
            os.path.join(OUTPUT_DIR, "final", wc.sm, "hprc_r1", "assembly_qc", "nucflag", f"{VERSION}_{DTYPE}")
        )
    threads:
        4
    shell:
        """
        mkdir -p {params.tmp_dir}
        ln -sf $(realpath {input.first_bw}) {params.tmp_dir}/{params.assembly_id}.nucflag.first.bw
        ln -sf $(realpath {input.second_bw}) {params.tmp_dir}/{params.assembly_id}.nucflag.second.bw
        ln -sf $(realpath {input.bedfile}) {params.tmp_dir}/{params.assembly_id}.nucflag.bed
        plot_tarball=$(realpath "{params.tmp_dir}/{params.assembly_id}.nucflag.plots.tar.gz")
        pushd {input.plot_dir}
        tar -czf ${{plot_tarball}} *.png
        popd
        pushd {params.tmp_dir}
        ls | xargs -P {threads} -I {{}} bash -c "md5sum {{}} > {{}}.md5"
        popd
        touch {output}
        """


rule nucflag:
    input:
        expand(rules.check_asm_nucflag.output, sm=SAMPLES),
        expand(rules.convert_nucflag_to_bed9.output, sm=SAMPLES),
        expand(rules.merge_first_bigwigs.output, sm=SAMPLES),
        expand(rules.merge_second_bigwigs.output, sm=SAMPLES),
        expand(rules.create_tarballs.output, sm=SAMPLES),
    default_target: True
