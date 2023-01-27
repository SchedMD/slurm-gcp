#!/bin/bash
set -eo pipefail

cd /opt/apps
wget https://github.com/alexdobin/STAR/archive/2.7.10a.tar.gz 
wget https://github.com/FelixKrueger/TrimGalore/archive/refs/tags/0.6.7.zip
wget https://github.com/deweylab/RSEM/archive/v1.3.3.tar.gz
wget https://github.com/StevenWingett/FastQ-Screen/archive/refs/tags/v0.15.2.zip 
wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip 
wget https://github.com/samtools/samtools/releases/download/1.15.1/samtools-1.15.1.tar.bz2
wget https://github.com/jgm/pandoc/releases/download/2.19.2/pandoc-2.19.2-linux-amd64.tar.gz
wget http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.10_amd64.deb
wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-ubuntu64.tar.gz
wget https://github.com/broadinstitute/gatk/releases/download/4.3.0.0/gatk-4.3.0.0.zip
apt-get install ./libssl1.0.0_1.0.2n-1ubuntu5.10_amd64.deb

tar -xzvf 2.7.10a.tar.gz 
unzip 0.6.7.zip
tar -xzvf v1.3.3.tar.gz
unzip v0.15.2.zip 
unzip fastqc_v0.11.9.zip
tar -vxf samtools-1.15.1.tar.bz2
tar -xvf pandoc-2.19.2-linux-amd64.tar.gz
tar -vxzf sratoolkit.tar.gz
unzip gatk-4.3.0.0.zip

chmod +x /opt/apps/FastQC/fastqc

#install STAR
cd /opt/apps/STAR-2.7.10a/source
make

#install RSEM
cd /opt/apps/RSEM-1.3.3
make
make install

#install SAMTOOLS
cd /opt/apps/samtools-1.15.1
./configure --prefix=/opt/apps/
make
make install

#CLEANUP
cd /opt/apps
# rm cellranger-7.0.0.tar.gz
rm v0.15.2.zip
rm fastqc_v0.11.9.zip
rm v1.3.3.tar.gz
rm 0.6.7.zip
rm samtools-1.15.1.tar.bz2

# install google cloud SDK to replace snap version

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update && sudo apt-get install google-cloud-cli

#install pip2
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
python2 get-pip.py
rm get-pip.py

pip3 install --upgrade requests