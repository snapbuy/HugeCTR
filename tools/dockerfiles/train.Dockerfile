FROM nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04 AS devel

ARG SM="60;61;70;75;80"
ARG VAL_MODE=OFF
ARG ENABLE_MULTINODES=ON
ARG NCCL_A2A=ON
ARG RELEASE=false

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        vim gdb git wget tar unzip curl python-dev python3-dev \
        zlib1g-dev lsb-release ca-certificates clang-format libboost-all-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/tmp && wget -q -nc --no-check-certificate -P /var/tmp http://repo.anaconda.com/miniconda/Miniconda3-4.7.12-Linux-x86_64.sh && \
    bash /var/tmp/Miniconda3-4.7.12-Linux-x86_64.sh -b -p /opt/conda && \
    /opt/conda/bin/conda init && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    /opt/conda/bin/conda clean -afy && \
    rm -rf /var/tmp/Miniconda3-4.7.12-Linux-x86_64.sh
ENV CPATH=/opt/conda/include:$CPATH \
    LD_LIBRARY_PATH=/opt/conda/lib:$LD_LIBRARY_PATH \
    LIBRARY_PATH=/opt/conda/lib:$LIBRARY_PATH \
    PATH=/opt/conda/bin:$PATH \
    CONDA_PREFIX=/opt/conda \
    NCCL_LAUNCH_MODE=PARALLEL

RUN conda update -n base -c defaults conda && \
    conda install -c rapidsai -c nvidia -c numba -c conda-forge cudf=0.18 python=3.8 cudatoolkit=11.0 && \
    conda install -c conda-forge cmake=3.19.6 pip ucx libhwloc=2.4.0 openmpi=4.1.0 openmpi-mpicc=4.1.0 mpi4py=3.0.3 && \
    conda clean -afy && \
    rm -rfv /opt/conda/include/nccl.h /opt/conda/lib/libnccl* /opt/conda/include/google /opt/conda/include/*cudnn* /opt/conda/lib/*cudnn*
ENV OMPI_MCA_plm_rsh_agent=sh

RUN echo alias python='/usr/bin/python3' >> /etc/bash.bashrc && \
    pip3 install numpy pandas sklearn ortools jupyter torch tqdm tensorflow==2.4.0 && \
    pip3 cache purge

# HugeCTR
RUN if [ "$RELEASE" = "true" ]; \
    then \
      mkdir -p /var/tmp && cd /var/tmp && git clone --depth=1 --branch master https://github.com/NVIDIA/HugeCTR.git HugeCTR && cd - && \
      cd /var/tmp/HugeCTR && \
      git submodule update --init --recursive && \
      mkdir build && cd build && \
      cmake -DCMAKE_BUILD_TYPE=Release -DSM=$SM \
            -DVAL_MODE=$VAL_MODE -DENABLE_MULTINODES=$ENABLE_MULTINODES -DNCCL_A2A=$NCCL_A2A .. && \
      make -j$(nproc) && make install && \
      chmod +x /usr/local/hugectr/bin/* && \
      chmod +x /usr/local/hugectr/lib/* && \
      rm -rf /var/tmp/HugeCTR; \
    else \
      echo "Build container for development successfully"; \
    fi
ENV PATH=/usr/local/hugectr/bin:$PATH \
    LIBRARY_PATH=/usr/local/hugectr/lib:$LIBRARY_PATH \
    LD_LIBRARY_PATH=/usr/local/hugectr/lib:$LD_LIBRARY_PATH \
    PYTHONPATH=/usr/local/hugectr/lib:$PYTHONPATH
