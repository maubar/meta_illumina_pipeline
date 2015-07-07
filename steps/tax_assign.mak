# Homology search pipeline

# Author: Mauricio Barrientos-Somarribas
# Email:  mauricio.barrientos@ki.se

# Copyright 2014 Mauricio Barrientos-Somarribas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#Make parameters
SHELL := /bin/bash

ifndef sample_name
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef ctg_folder
$(error Variable 'ctg_folder' is not defined)
endif

ifndef read_steps
read_steps := qf_rmcont_asm
$(info 'read_steps' is assumed to be $(read_steps))
endif

ifndef ctg_steps
ctg_steps := qf_rmcont_asm
$(info 'ctg_steps' is assumed to be $(ctg_steps))
endif

ifndef step
step:= tax
$(warning Variable 'step' has been defined as '$(step)')
endif

#Run params
ifndef threads
	$(error Define threads variable in make.cfg file)
endif

#Input and Output file prefixes
IN_CTG_PREFIX := $(sample_name)_$(ctg_steps)
IN_READ_PREFIX := $(sample_name)_$(read_steps)
OUT_PREFIX:= $(IN_CTG_PREFIX)_$(step)

#Blast parameters
blast_params:= -evalue 1 -num_threads $(threads) -max_target_seqs 10 -outfmt 5 -show_gis
megablast_params:= -reward 2 -penalty -3 -gapopen 5 -gapextend 2
blastn_params:= -reward 4 -penalty -5 -gapopen 12 -gapextend 8

ctg_outfile = $(1)/$(IN_CTG_PREFIX)_allctgs_$(2)
read_outfiles = $(addsuffix _$(2),$(addprefix $(1)/$(IN_READ_PREFIX)_,$(3)))

#Delete produced files if step fails
.DELETE_ON_ERROR:
#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.INTERMEDIATE: $(TMP_DIR)/%.fa

.PHONY: all
.PHONY: kraken_reports blastn_vir blastn_nt
.PHONY: blastp_vir blastp_nr blastp_sprot
.PHONY: blastx_vir blastx_nr blastx_sprot
.PHONY: hmmscan_pfam hmmscan_vfam phmmer_vir phmmer_sprot

all: kraken_reports
all: diamond_nr
all: blastn_nt
# all: blastx_nr
# all: blastx_vir
# all: blastx_sprot
# all: hmmscan_pfam hmmscan_vfam
# all: phmmer_vir
# all: blastp_vir blastp_nr

#Outputs

kraken_reports: $(call ctg_outfile,kraken,kraken.report)
#kraken_reports: $(call read_outfiles,kraken,kraken.report,pe se)

phmmer_vir : $(call ctg_outfile,phmmer,fgs_phmmer_refseqvir.tbl)
phmmer_sprot : $(call ctg_outfile,phmmer,fgs_phmmer_sprot.tbl)

hmmscan_pfam : $(call ctg_outfile,hmmscan,fgs_hmmscan_pfam.tbl)
hmmscan_pfam : $(call read_outfiles,hmmscan,fgs_hmmscan_pfam.tbl,pe se)

hmmscan_vfam : $(call ctg_outfile,hmmscan,fgs_hmmscan_vfam.tbl)
hmmscan_vfam : $(call read_outfiles,hmmscan,fgs_hmmscan_vfam.tbl,pe se)

blastn_nt : $(call ctg_outfile,blastn,blastn_nt.xml)
blastn_nt : $(call read_outfiles,blastn,blastn_nt.xml,pe se)

blastn_vir : $(call ctg_outfile,blastn,blastn_refseqvir.xml)
blastn_vir : $(call read_outfiles,blastn,blastn_refseqvir.xml,pe se)

blastp_vir : $(call ctg_outfile,blastp,fgs_blastp_refseqvir.xml)
blastp_vir : $(call read_outfiles,blastp,fgs_blastp_refseqvir.xml,pe se)

blastp_nr : $(call ctg_outfile,blastp,fgs_blastp_nr.xml)
blastp_nr : $(call read_outfiles,blastp,fgs_blastp_nr.xml,pe se)

blastp_sprot : $(call ctg_outfile,blastp,fgs_blastp_sprot.xml)
blastp_sprot : $(call read_outfiles,blastp,fgs_blastp_sprot.xml,pe se)

blastx_nr : $(call ctg_outfile,blastx,blastx_nr.xml)
blastx_nr : $(call read_outfiles,blastx,blastx_nr.xml,pe se)

diamond_nr : $(call ctg_outfile,diamond,diamond_nr.sam)
diamond_nr : $(call read_outfiles,diamond,diamond_nr.sam,pe se)

blastx_sprot : $(call ctg_outfile,blastx,blastx_sprot.xml)
blastx_sprot : $(call read_outfiles,blastx,blastx_sprot.xml,pe se)

blastx_vir : $(call ctg_outfile,blastx,blastx_refseqvir.xml)
blastx_vir : $(call read_outfiles,blastx,blastx_refseqvir.xml,pe se)

#*************************************************************************
#Call to Kraken - Salzberg
#*************************************************************************
#Other flags: --fastq-input
kraken/%_kraken.out: $(ctg_folder)/%.fa
	mkdir -p kraken
	@echo -e "\nClassifying $* with Kraken\n\n"
	kraken --preload --db $(kraken_db) --threads $(threads) $^ > $@

%_kraken.report: %_kraken.out
	@echo -e "\nCreating Kraken report for $* \n\n"
	kraken-report --db $(kraken_db) $^ > $@

#*************************************************************************
#FragGeneScan
#*************************************************************************
#Contig analysis
fgs/%_fgs.faa: $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(FGS_BIN) -genome=$^ -out=$(basename $@) -complete=0 -train=illumina_10

#Read analysis
fgs/%_fgs.faa : $(read_folder)/%.fa
	mkdir -p $(dir $@)
	$(FGS_BIN) -genome=$< -out=$(basename $@) -complete=0 -train=illumina_10

#*************************************************************************
#Phmmer
#*************************************************************************
#Optional --domtblout $(basename $@).dom

#Contigs against swissprot
phmmer/%_fgs_phmmer_sprot.tbl : fgs/%_fgs.faa $(swissprot_faa)
	mkdir -p phmmer
	$(PHMMER_BIN) --cpu $(threads) --noali --tblout $@ --domtblout $(basename $@)_dom.tbl $^ > /dev/null

#Contigs against refseq virus proteins
phmmer/%_fgs_phmmer_refseqvir.tbl : fgs/%_fgs.faa $(refseq_virus_faa)
	mkdir -p phmmer
	$(PHMMER_BIN) --cpu $(threads) --noali --tblout $@ --domtblout $(basename $@)_dom.tbl $^ > /dev/null

#*************************************************************************
#HMMSCAN
#*************************************************************************
#Optional --domtblout $(basename $@).dom

#Contigs against pfam
hmmscan/%_fgs_hmmscan_pfam.tbl : $(pfam_hmm_db) fgs/%_fgs.faa
	mkdir -p $(dir $@)
	$(HMMSCAN_BIN) --cpu $(threads) --noali --tblout $@ --domtblout $(basename $@)_dom.tbl $^ > /dev/null

#Contigs against vFam (Skewes-Cox,2014)
hmmscan/%_fgs_hmmscan_vfam.tbl : $(vfam_hmm_db) fgs/%_fgs.faa
	mkdir -p $(dir $@)
	$(HMMSCAN_BIN) --cpu $(threads) --noali --tblout $@ --domtblout $(basename $@)_dom.tbl $^ > /dev/null

#*************************************************************************
#BlastN - Nucleotides
#*************************************************************************
#Reads to Refseq Viral nucleotides
blastn/%_blastn_refseqvir.xml: $(read_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTN_BIN) -task blastn $(blast_params) $(blastn_params) -db $(blastdb_refseqvir_nucl) -query $^ -out $@

#Contigs to Refseq Viral nucleotides
blastn/%_blastn_refseqvir.xml: $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTN_BIN) -task blastn $(blast_params) $(blastn_params) -db $(blastdb_refseqvir_nucl) -query $^ -out $@

#Contigs to nt
blastn/%_blastn_nt.xml: $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTN_BIN) -task blastn $(blast_params) $(blastn_params) -db $(blastdb_nt) -query $^ -out $@

#*************************************************************************
#BlastX - Proteins
#*************************************************************************
#Contigs to NR
blastx/%_blastx_nr.xml : $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTX_BIN) $(blast_params) -db $(blastdb_nr) -query $< -out $@

#Reads to NR
blastx/%_blastx_nr.xml : $(read_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTX_BIN) $(blast_params) -db $(blastdb_nr) -query $< -out $@

#Contigs to Swissprot
blastx/%_blastx_sprot.xml : $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTX_BIN) $(blast_params) -db $(blastdb_sprot) -query $< -out $@

#Contigs to Refseq Virus Proteins
blastx/%_blastx_refseqvir.xml : $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTX_BIN) $(blast_params) -db $(blastdb_refseqvir_prot) -query $< -out $@

#Reads to Refseq Virus Proteins
blastx/%_blastx_refseqvir.xml : $(read_folder)/%.fa
	mkdir -p $(dir $@)
	$(BLASTX_BIN) $(blast_params) -db $(blastdb_refseqvir_prot) -query $< -out $@

#*************************************************************************
#Diamond (Tubingen) - Proteins
#*************************************************************************
#Contigs to NR
#Can add --sensitive flag for slower but more accurate results
#--seg yes/no for low complexity masking
diamond/%_diamond_nr.daa : $(ctg_folder)/%.fa
	mkdir -p $(dir $@)
	$(DIAMOND_BIN) blastx --sensitive -p $(threads) --db $(diamond_nr) --query $< --daa $@ --tmpdir $(TMP_DIR) --seg yes

diamond/%_diamond_nr.daa : $(read_folder)/%.fa
	mkdir -p $(dir $@)
	$(DIAMOND_BIN) blastx --sensitive -p $(threads) --db $(diamond_nr) --query $< --daa $@ --tmpdir $(TMP_DIR) --seg yes

diamond/%.sam.gz : diamond/%.daa
	$(DIAMOND_BIN) view --daa $^ --out $(dir $@)/$*.sam --outfmt sam
	gzip $(dir $@)/$*.sam

#*************************************************************************
#BlastP - Predicted ORF to Proteins
#*************************************************************************
blastp/%_fgs_blastp_nr.xml: fgs/%_fgs.faa
	mkdir -p $(dir $@)
	$(BLASTP_BIN) $(blast_params) -db $(blastdb_nr) -query $< -out $@

blastp/%_fgs_blastp_sprot.xml: fgs/%_fgs.faa
	mkdir -p $(dir $@)
	$(BLASTP_BIN) $(blast_params) -db $(blastdb_sprot) -query $< -out $@

blastp/%_fgs_blastp_refseqvir.xml: fgs/%_fgs.faa
	mkdir -p $(dir $@)
	$(BLASTP_BIN) $(blast_params) -db $(blastdb_refseqvir_prot) -query $< -out $@

#*************************************************************************
#CLEANING RULES
#*************************************************************************
.PHONY: clean-tmp

clean-tmp:
	-rm $(TMP_DIR)/*.fa
