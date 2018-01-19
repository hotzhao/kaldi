#!/bin/bash
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0


# To be run from ..
# Flat start and monophone training, with delta-delta features.
# This script applies cepstral mean normalization (per speaker).

DATA_ROOT=/home/liang/work/speech/corpus/voxforge
selected=$DATA_ROOT/selected

# Begin configuration section.
nj=1
cmd=run.pl
scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
num_iters=40    # Number of iterations of training
max_iter_inc=30 # Last iter to increase #Gauss on.
totgauss=1000 # Target #Gaussians.
careful=false
boost_silence=1.0 # Factor by which to boost silence likelihoods in alignment
realign_iters="1 2 3 4 5 6 7 8 9 10 12 14 16 18 20 23 26 29 32 35 38";
config= # name of config file.
stage=-4
power=0.25 # exponent to determine number of gaussians from occurrence counts
norm_vars=false # deprecated, prefer --cmvn-opts "--norm-vars=false"
cmvn_opts=  # can be used to add extra options to cmvn.
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 0 ]; then
  echo "Usage: steps/train_mono.sh [options] <data-dir> <lang-dir> <exp-dir>"
  echo " e.g.: steps/train_mono.sh data/train.1k data/lang exp/mono"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --nj <nj>                                        # number of parallel jobs"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  exit 1;
fi

data=$selected/train.1k
lang=$selected/lang
dir=/home/liang/work/speech/kaldi/egs/voxforge/s5/lz

oov_sym=`cat $lang/oov.int` || exit 1;

mkdir -p $dir/log
echo $nj > $dir/num_jobs
sdata=$data/split$nj;
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;

cp $lang/phones.txt $dir || exit 1;

$norm_vars && cmvn_opts="--norm-vars=true $cmvn_opts"
echo $cmvn_opts  > $dir/cmvn_opts # keep track of options to CMVN.

feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas ark:- ark:- |"
example_feats="`echo $feats | sed s/JOB/1/g`";

echo "$0: Initializing monophone system."

[ ! -f $lang/phones/sets.int ] && exit 1;
shared_phones_opt="--shared-phones=$lang/phones/sets.int"

if [ $stage -le -3 ]; then
  # Note: JOB=1 just uses the 1st part of the features-- we only need a subset anyway.
  if ! feat_dim=`feat-to-dim "$example_feats" - 2>/dev/null` || [ -z $feat_dim ]; then
    feat-to-dim "$example_feats" -
    echo "error getting feature dimension"
    exit 1;
  fi

  $cmd JOB=1 $dir/log/init.log \
    gmm-init-mono $shared_phones_opt "--train-feats=$feats subset-feats --n=10 ark:- ark:-|" $lang/topo $feat_dim \
    $dir/0.mdl $dir/tree || exit 1;
fi

echo "liang: exit for debug"
exit 1;

