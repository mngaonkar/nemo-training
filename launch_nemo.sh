#!/bin/sh

docker run --rm -it --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -v ./:/code/ nvcr.io/nvidia/nemo:24.07

