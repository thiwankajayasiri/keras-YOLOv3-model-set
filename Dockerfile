# Copyright 2018 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
#
# THIS IS A GENERATED DOCKERFILE.
#
# This file was assembled from multiple pieces, whose use is documented
# throughout. Please refer to the TensorFlow dockerfiles documentation
# for more information.

MAINTAINER Xiaobin Zhang <david8862@gmail.com>

ARG UBUNTU_VERSION=18.04

ARG ARCH=
ARG CUDA=10.0
FROM nvidia/cuda${ARCH:+-$ARCH}:${CUDA}-base-ubuntu${UBUNTU_VERSION} as base
# ARCH and CUDA are specified again because the FROM directive resets ARGs
# (but their default value is retained if set previously)
ARG ARCH
ARG CUDA
ARG CUDNN=7.4.1.5-1
ARG CUDNN_MAJOR_VERSION=7
ARG LIB_DIR_PREFIX=x86_64

# Needed for string substitution
SHELL ["/bin/bash", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cuda-command-line-tools-${CUDA/./-} \
        cuda-cublas-dev-${CUDA/./-} \
        cuda-cudart-dev-${CUDA/./-} \
        cuda-cufft-dev-${CUDA/./-} \
        cuda-curand-dev-${CUDA/./-} \
        cuda-cusolver-dev-${CUDA/./-} \
        cuda-cusparse-dev-${CUDA/./-} \
        libcudnn7=${CUDNN}+cuda${CUDA} \
        libcudnn7-dev=${CUDNN}+cuda${CUDA} \
        libcurl3-dev \
        libfreetype6-dev \
        libhdf5-serial-dev \
        libzmq3-dev \
        pkg-config \
        rsync \
        software-properties-common \
        unzip \
        zip \
        zlib1g-dev \
        wget \
        git \
        && \
    find /usr/local/cuda-${CUDA}/lib64/ -type f -name 'lib*_static.a' -not -name 'libcudart_static.a' -delete && \
    rm /usr/lib/${LIB_DIR_PREFIX}-linux-gnu/libcudnn_static_v7.a


# Configure the build for our CUDA configuration.
ENV CI_BUILD_PYTHON python
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:/usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENV TF_NEED_CUDA 1
ENV TF_NEED_TENSORRT 1
ENV TF_CUDA_COMPUTE_CAPABILITIES=3.5,5.2,6.0,6.1,7.0
ENV TF_CUDA_VERSION=${CUDA}
ENV TF_CUDNN_VERSION=${CUDNN_MAJOR_VERSION}
# CACHE_STOP is used to rerun future commands, otherwise cloning tensorflow will be cached and will not pull the most recent version
ARG CACHE_STOP=1
# Check out TensorFlow source code if --build-arg CHECKOUT_TF_SRC=1
#ARG CHECKOUT_TF_SRC=0
#RUN test "${CHECKOUT_TF_SRC}" -eq 1 && git clone https://github.com/tensorflow/tensorflow.git /tensorflow_src || true

# Link the libcuda stub to the location where tensorflow is searching for it and reconfigure
# dynamic linker run-time bindings
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 \
    && echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/z-cuda-stubs.conf \
    && ldconfig

ARG USE_PYTHON_3_NOT_2
ARG _PY_SUFFIX=${USE_PYTHON_3_NOT_2:+3}
ARG PYTHON=python${_PY_SUFFIX}
ARG PIP=pip${_PY_SUFFIX}

# See http://bugs.python.org/issue19846
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y \
    ${PYTHON} \
    ${PYTHON}-pip

RUN ${PIP} --no-cache-dir install --upgrade \
    pip \
    setuptools

# Some TF tools expect a "python" binary
RUN ln -s $(which ${PYTHON}) /usr/local/bin/python 

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    wget \
    openjdk-8-jdk \
    ${PYTHON}-dev \
    virtualenv \
    swig

# Install python packages
RUN ${PIP} --no-cache-dir install \
    Pillow \
    h5py \
    keras_applications \
    keras_preprocessing \
    matplotlib \
    mock \
    numpy \
    scipy \
    sklearn \
    pandas \
    future \
    portpicker \
    && test "${USE_PYTHON_3_NOT_2}" -eq 1 && true || ${PIP} --no-cache-dir install \
    tensorflow-gpu \
    keras \
    enum34

# Change workdir
WORKDIR /root

# Prepare code & dataset (PascalVOC)
RUN git clone https://github.com/david8862/keras-YOLOv3-mobilenet.git && \
    mkdir -p data/PascalVOC && \
    wget -O data/PascalVOC/VOCtest_06-Nov-2007.tar http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCtest_06-Nov-2007.tar && \
    wget -O data/PascalVOC/VOCtrainval_06-Nov-2007.tar http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCtrainval_06-Nov-2007.tar && \
    wget -O data/PascalVOC/VOCtrainval_11-May-2012.tar http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCtrainval_11-May-2012.tar && \
    pushd data/PascalVOC && \
    tar xf VOCtest_06-Nov-2007.tar && \
    tar xf VOCtrainval_06-Nov-2007.tar && \
    tar xf VOCtrainval_11-May-2012.tar && \
    popd && \
    pushd keras-YOLOv3-mobilenet/tools/ && \
    python voc_annotation.py --dataset_path=/root/data/PascalVOC/VOCdevkit/ --output_path=/root/data/PascalVOC && \
    popd && \
    pushd data/PascalVOC && cp -rf 2007_train.txt trainval.txt && cat 2007_val.txt >> trainval.txt && cat 2012_train.txt >> trainval.txt && cat 2012_val.txt >> trainval.txt && \
    cp -rf trainval.txt 2007_test.txt /root/keras-YOLOv3-mobilenet/ && \
    popd && \
    wget -O keras-YOLOv3-mobilenet/model_data/yolov3.weights https://pjreddie.com/media/files/yolov3.weights && \
    wget -O keras-YOLOv3-mobilenet/model_data/yolov3-tiny.weights https://pjreddie.com/media/files/yolov3-tiny.weights && \
    wget -O keras-YOLOv3-mobilenet/model_data/darknet53.conv.74.weights https://pjreddie.com/media/files/darknet53.conv.74 && \
    pushd keras-YOLOv3-mobilenet/tools/ && \
    python convert.py yolov3.cfg ../model_data/yolov3.weights ../model_data/yolov3.h5 && \
    python convert.py yolov3-tiny.cfg ../model_data/yolov3-tiny.weights ../model_data/tiny_yolo_weights.h5 && \
    python convert.py darknet53.cfg ../model_data/darknet53.conv.74.weights ../model_data/darknet53_weights.h5 && \
    popd

# Optional: Prepare MS COCO 2017 dataset
#RUN mkdir -p data/COCO2017 && \
    #wget -O data/COCO2017/train2017.zip http://images.cocodataset.org/zips/train2017.zip && \
    #wget -O data/COCO2017/val2017.zip http://images.cocodataset.org/zips/val2017.zip && \
    #wget -O data/COCO2017/test2017.zip http://images.cocodataset.org/zips/test2017.zip && \
    #wget -O data/COCO2017/annotations_trainval2017.zip http://images.cocodataset.org/annotations/annotations_trainval2017.zip && \
    #wget -O data/COCO2017/image_info_test2017.zip http://images.cocodataset.org/annotations/image_info_test2017.zip && \
    #pushd data/COCO2017 && \
    #unzip -e train2017.zip && unzip -e val2017.zip && unzip -e test2017.zip && \
    #unzip -e annotations_trainval2017.zip && unzip -e image_info_test2017.zip && \
    #popd && \
    #pushd keras-YOLOv3-mobilenet/tools/ && \
    #python coco_annotation.py --dataset_path=/root/data/COCO2017/ --output_path=/root/data/COCO2017 && \
    #pushd data/COCO2017 && cp -rf train2017.txt trainval.txt && cat val2017.txt >> trainval.txt && \
    #cp -rf trainval.txt /root/keras-YOLOv3-mobilenet/ && \
    #popd



#COPY bashrc /etc/bash.bashrc
#RUN chmod a+rwx /etc/bash.bashrc
