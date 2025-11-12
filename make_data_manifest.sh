#!/bin/bash

set -euo pipefail

aws s3 ls s3://human-pangenomics/submissions/8A3BE2F8-37EE-4D50-9173-15A493A386D8--HPRC_Y1_QC_NUCFLAG/ --recursive | \
awk -v OFS="\t" '{
    file=$4;
    match($4, "/([^/]+)\\.nucflag", samples)
    if ( file ~ ".bed.md5") {
        if (!(file ~ "nucflag_v2")) { next }
        ftype="bedfile_hash"
    } else if ( file ~ ".bed") {
        if (!(file ~ "nucflag_v2")) { next }
        ftype="bedfile"
    } else if ( file ~ ".tar.gz.md5") {
        ftype="plot_tarball_hash"
    } else if ( file ~ ".tar.gz") {
        ftype="plot_tarball"
    } else if ( file ~ ".first.bw.md5") {
        ftype="bw_first_hash"
    } else if ( file ~ ".first.bw") {
        ftype="bw_first"
    } else if ( file ~ ".second.bw.md5") {
        ftype="second_bw_hash"
    } else if ( file ~ ".second.bw") {
        ftype="second_bw"
    } else {
        next
    }
    url="https://s3-us-west-2.amazonaws.com/human-pangenomics/"file
    uri="s3://human-pangenomics/"file
    print samples[1], ftype, url, uri
}' | \
sort -k2,2 -k1,1