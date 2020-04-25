#!/bin/bash
export TORCH_VERSION=1.3.1
export SOFTWARE_ROOT="/project/k01/shaima0d/software/cle7up01"
export BLD_DIR="${SOFTWARE_ROOT}/build/pytorch-${TORCH_VERSION}"
export PREFIX="${SOFTWARE_ROOT}/apps/pytorch/${TORCH_VERSION}_mkl"
export MODULEPATH=$SOFTWARE_ROOT/modulefiles:$MODULEPATH
function set_env {
module load cmake
module swap PrgEnv-$(echo ${PE_ENV}|tr [:upper:] [:lower:]) PrgEnv-gnu
module load mkl
module load intel-python
module load cray-fftw
module list
export CRAYPE_LINK_TYPE=dynamic
}


function get_source {
echo "Running git clone recipe"
     	git clone --recursive -b v${TORCH_VERSION} https://github.com/pytorch/pytorch pytorch-${TORCH_VERSION}
	if [ -d ${BLD_DIR} ]; then
		cd ${BLD_DIR}
		# if you are updating an existing checkout
		git submodule sync
		git submodule update --init --recursive
	fi
}

function build() {
echo "Running build recipe."
cd ${BLD_DIR}
if [ -d "./build" ]
 then
	rm -rf ./build/*
else
	mkdir build 
fi
cd build

cmake -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=CC FC=ftn MPICC=cc MPICXX=CC \
	-DUSE_NATIVE_ARCH=OFF -DUSE_CUDA=OFF -DUSE_CUDNN=OFF -DUSE_SYSTEM_NCCL=OFF\
	-DUSE_OPENMP=ON  -DUSE_MKLDNN_CBLAS=ON -DBLAS=MKL -DUSE_QNNPACK=ON -DUSE_FBGEMM=OFF\
	-DUSE_PYTORCH_QNNPACK=ON -DUSE_DISTRIBUTED=ON  -DUSE_MKLDNN=ON \
	-DINTEL_MKL_DIR=$MKLROOT -DUSE_GLOO=OFF -DUSE_ROCM=OFF \
	-DCMAKE_C_FLAGS="-craype-verbose -march=haswell" -DCMAKE_CXX_FLAGS="-craype-verbose -march=haswell" \
	-DPYTORCH_BUILD_VERSION='1.3.1' -DPYTORCH_BUILD_NUMBER=1 \
	-DBUILD_PYTHON=ON \
	-DFFTW3_INCLUDE_DIR='/opt/cray/pe/fftw/3.3.8.4/haswell/include' -DLIBFFTW3='/opt/cray/pe/fftw/3.3.8.4/haswell/lib' \
	-DCMAKE_INSTALL_PREFIX=$PREFIX \
	..
files=$(grep -r isystem . |cut -d ':' -f 1) && echo $files | xargs sed -i 's;-isystem\ \/;-I\/;g' $files
if [ $? -eq 0 ]
   then
   	make -j 32 VERBOSE=1
fi
cd ${BLD_DIR}
export PYTHONPATH=$PREFIX/lib/python3.7/site-packages:$PYTHONPATH
LDFLAGS=$(echo -L${BLD_DIR}/build/lib)
LDFLAGS=$LDFLAGS python setup.py install --prefix=$PREFIX
}


ARG=$1
if [ ${ARG} = "all" ] || [ "${ARG}x" = "x" ]
 then
	set_env
	get_source
	build
elif [ ${ARG} = "build" ] 
 then
	set_env
	build
fi

