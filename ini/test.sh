#!/bin/bash

source ./ini.sh
read_file ./config.ini test
echo ${all_option["aa"]}
echo ${all_option["bb"]}