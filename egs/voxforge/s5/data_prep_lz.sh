#!/bin/bash

source path.sh

DATA=~/work/voice/corpus/voxforge/selected
locdata=$DATA/local
loctmp=$locdata/tmp
logdir=exp/data_prep

rm $locdata/spk2gender.tmp 2>/dev/null

#for d in $(find ${DATA}/ -mindepth 1 -maxdepth 1 -type l -or -type d); do
#  basename $d
#done | awk 'BEGIN {FS="-"} NR==FNR{arr[$1]; next;} ($1 in arr)' \
#  $loctmp/speakers_test.txt - | sort > $loctmp/dir_test.txt

#for d in $(find ${DATA}/ -mindepth 1 -maxdepth 1 -type l -or -type d); do
#  basename $d;
#done | awk 'BEGIN {FS="-"} NR==FNR{arr[$1]; next;} ($1 in arr)' \
#  $loctmp/speakers_train.txt - | sort > $loctmp/dir_train.txt

for s in test train; do
  echo "--- Preparing ${s}_wav.scp, ${s}_trans.txt and ${s}.utt2spk ..."
  
  for d in $(cat $loctmp/dir_${s}.txt); do
    spkname=`echo $d | cut -f1 -d'-'`;
    spksfx=`echo $d | cut -f2 -d'-'`;
    idpfx="${spkname}-${spksfx}";
    dir=${DATA}/$d

    rdm=`find $dir/etc/ -iname 'readme'`  
    if [ -z $rdm ]; then
      echo "No readme file for $d - skipping this directory ..."      
      continue
    fi

    spkgender=`perl -ne 'm/.*gender\:\W*(.).*/i && print lc($1)' < $rdm `
    if [ "$spkgender" != "f" ] && [ "$spkgender" != "m" ]; then
      echo "Illegal or empty gender ($spkgender) for \"$d\" - assuming m(ale) ..."
      spkgender="m"
    fi
    echo "$spkname $spkgender" >> $locdata/spk2gender.tmp

    if [ ! -f ${dir}/etc/PROMPTS ]; then
      echo "No etc/PROMPTS file exists in $dir - skipping the dir ..." \
        >> $logdir/make_trans.log
      continue
    fi

    if [ -d ${dir}/wav ]; then
      wavtype=wav
    elif [ -d ${dir}/flac ]; then
      wavtype=flac
    else
      echo "No 'wav' or 'flac' dir in $dir - skipping ..."
      continue
    fi

    all_wavs=()
    all_utt2spk_entries=()
    for w in ${dir}/${wavtype}/*${wavtype}; do
      bw=`basename $w`
      wavname=${bw%.$wavtype} #LZ: quite tricky: delete .wav from back of $bw
      all_wavs+=("$wavname")
      id="${idpfx}-${wavname}"
      if [ ! -s $w ]; then
        echo "$w is zero-size - skipping ..." 1>&2
        continue
      fi
      if [ $wavtype == "wav" ]; then
        echo "$id $w"
      else
        echo "$id flac -c -d --silent $w |"
      fi
      all_utt2spk_entries+=("$id $spkname")
    done >> ${loctmp}/${s}_wav.scp.unsorted 
    
    for a in "${all_utt2spk_entries[@]}"; do echo $a; done >> $loctmp/${s}.utt2spk.unsorted    
    
    if [ ! -f ${loctmp}/${s}_wav.scp.unsorted ]; then
      echo "$0: processed no data: error: pattern ${dir}/${wavtype}/*${wavtype} might match nothing"
      exit 1;
    fi

    local/make_trans.py $dir/etc/PROMPTS ${idpfx} "${all_wavs[@]}" \
      2>>${logdir}/make_trans.log >> ${loctmp}/${s}_trans.txt.unsorted

  done

  # filter out the audio for which there is no proper transcript
  awk 'NR==FNR{trans[$1]; next} ($1 in trans)' FS=" " \
    ${loctmp}/${s}_trans.txt.unsorted ${loctmp}/${s}_wav.scp.unsorted |\
   sort -k1 > ${locdata}/${s}_wav.scp
  
  awk 'NR==FNR{trans[$1]; next} ($1 in trans)' FS=" " \
    ${loctmp}/${s}_trans.txt.unsorted $loctmp/${s}.utt2spk.unsorted |\
   sort -k1 > ${locdata}/${s}.utt2spk
  
  sort -k1 < ${loctmp}/${s}_trans.txt.unsorted > ${locdata}/${s}_trans.txt

  echo "--- Preparing ${s}.spk2utt ..."
  cat $locdata/${s}_trans.txt |\
  cut -f1 -d' ' |\
  awk 'BEGIN {FS="-"}
        {names[$1]=names[$1] " " $0;}
        END {for (k in names) {print k, names[k];}}' | sort -k1 > $locdata/${s}.spk2utt
done;

awk '{spk[$1]=$2;} END{for (s in spk) print s " " spk[s]}' \
  $locdata/spk2gender.tmp | sort -k1 > $locdata/spk2gender



