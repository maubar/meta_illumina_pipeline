
process trimgalore_qf{

  script:
  """
  trim_galore -q 20 --fastqc --fastqc_args "-k 10 -t 16" --illumina --paired --gzip \
  	--stringency 5 --length 60 --output_dir ${OUT_DIR} --trim1 \
  	--retain_unpaired -r1 85 -r2 85 $(ls ${READS_DIR}/*.fastq.gz | sort)
  """
}

process remove_sispa_adapters_pe{
  script:
  """
  cutadapt --cut=3 -g ^GCCGGAGCTCTGCAGATATC -g ^GGAGCTCTGCAGATATC --no-indels --error-rate=0.1 -f 'fastq' \
    -o R1_PIPE ${IN_DIR}/*_val_1.fq.gz 2>&1 > log/${SAMPLE_ID}_overhangs_R1.log &

  cutadapt --cut=3 -g ^GCCGGAGCTCTGCAGATATC -g ^GGAGCTCTGCAGATATC --no-indels --error-rate=0.1 -f 'fastq' \
    -o R2_PIPE ${IN_DIR}/*_val_2.fq.gz 2>&1 > log/${SAMPLE_ID}_overhangs_R2.log &
  """
}

process remove_sispa_adapters_se{

  script:
  """
  #Merge unpaired into a single file
  cat ${IN_DIR}/*_unpaired_2.fq.gz >> ${IN_DIR}/*_unpaired_1.fq.gz && rm ${IN_DIR}/*_unpaired_2.fq.gz

  #Requires cutadapt
  cutadapt --cut=3 -g ^GCCGGAGCTCTGCAGATATC -g ^GGAGCTCTGCAGATATC --no-indels --error-rate=0.1 \
  	-o SE_PIPE ${IN_DIR}/*_unpaired_1.fq.gz 2>&1 > log/${SAMPLE_ID}_overhangs_unpaired.log &
  """
}

process remove_human_pe{
  script:
  """
  bowtie2 --local --very-sensitive-local -t -p 12 -x ${BOWTIE_DB} -1 R1_PIPE -2 R2_PIPE | tee >(samtools view -hSb - | samtools flagstat - > log/${SAMPLE_ID}_bowtie_pe.flagstat ) | samtools view -hSb -f12 -F256 - | samtools fastq - | gzip > ${OUT_FILE}
  """
}

process remove_human_se{
  script:
  """
  bowtie2 --local --very-sensitive-local -t -p 8 -x ${BOWTIE_DB} -U SE_PIPE | tee >(samtools view -hSb - | samtools flagstat - > log/${SAMPLE_ID}_bowtie_unpaired.flagstat ) | samtools view -hSb -f4 -F256 - | samtools fastq - | gzip > ${OUT_FILE}
  """
}

/**
ASSEMBLY STEPS
**/

process asm_megahit{


  output:
  file "megahit/final.contigs.fa" into asm_megahit_out

  script:
  """
  $(MEGAHIT_BIN) -m 5e10 -l $$(( 2*$(READ_LEN) )) --k-step 4 --k-max 81 --12 $< -r $(word 2,$^),$(word 3,$^) --cpu-only -t $(threads) -o megahit
  """

}

process asm_metaspades{
  output:
  file "spades/contigs.fasta" into asm_spades_out

  script:
  """
  $(SPADES_BIN) -t $(threads) --pe1-12 $< --pe1-s $(word 2,$^) --s1 $(word 3,$^) -o $(dir $@) --tmp-dir $(TMP_DIR) -m 64
  """
}

process asm_iva{

}

process asm_filter_contigs{
  script:
  """
  $(SEQTK_BIN) seq -L 500 $< | awk -vPREFIX=$*  'BEGIN {counter=1; split(PREFIX,fields,"_asm_"); ASM=fields[2];} /^>/ {print ">" ASM "_" counter ;counter+=1;} ! /^>/{print $0;}' > $@
  """
}


/**
NOTE: Map all as single ends maybe(?)
NOTE: Use BURST maybe or BBmap ?
*/
process asm_map_reads_to_contigs{
  script:
  """
  $(BWA_BIN) mem -t $(threads) -T 30 -M -p $(basename $(word 2,$^)) $< | $(SAMTOOLS_BIN) view -hSb -o $@ -
  """
}

/**
Taxonomical assignment
**/

process tax_reads_metaphlan{
  script:
  """
  ifndef TMP_DIR
  $(mpa_bin) --mpa_pkl $(mpa_pkl) --bowtie2db $(mpa_bowtie2db) \
  		--bowtie2out $(TMP_DIR )/nohuman.bowtie2.bz2 --nproc $(threads) --input_type multifastq \
  		--sample_id_key $(sample_name) --biom $*_nohuman_metaphlan.biom $< $(word 1,$@)
  """
}

process tax_reads_xxx{
  script:
  """
  """
}

process tax_diamond{

  script:
  """
  """
}
