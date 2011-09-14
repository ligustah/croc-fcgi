#!/bin/bash
dmd build.d lib/ini.d -ofbuild && ./build && rm ./build
