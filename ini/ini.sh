#!/bin/bash

declare -A all_option

all_section=()
all_option=()

function read_section()
{
    local file_path=$1
    all_section=$(awk -F '[][]' '/\[.*]/{print $2}' $file_path)	
}

function is_exist_section()
{
    [[ ${all_section[@]/$1/} != ${all_section[@]} ]]
    return $?
}

function read_file()
{    
    local file_path=$1
    local section=$2

    if [ ! -e $file_path ]; then
        echo "config file $file_path not exist!"
        return 1
    fi
    
    read_section $file_path    
    is_exist_section $section
    if [ $? = 1 ];then
       return 1	    
    fi	    

    local a=$(awk "/\[${section}\]/{a=1}a==1"  $file_path|sed -e'1d' -e '/^$/d'  -e 's/[ \t]*$//g' -e 's/^[ \t]*//g' -e 's/[ ]/@G@/g' -e '/^\[/,$d')
    local b=($a)
    
    all_option=()    
    for i in ${b[@]};do
        if [ -n ${i} ]||[ "${i}" i!="@S@" ];then
            local option=${i//@G@/}
            local key=${option%%=*}
            key=${key%\"}
            key=${key#\"}
            local value=${option##*=}
            value=${value%\"}
            value=${value#\"}
            all_option[${key}]=${value}
        fi
    done
    
    #echo "size:${#all_option[@]}"
    #echo "option:${all_option[@]}"
    return 0
}

function write_file()
{
   local file_path=$1
   local section=$2
   local item=$3
   local val=$4

   if [ ! -e $file_path ]; then
      echo "config file $file_path not exist!"
      return 1
   fi

   read_section $file_path
   is_exist_section $section
   if [ $? = 1 ];then
       return 1
   fi

   awk -F '=' '/\['${section}'\]/{a=1} (a==1 && "'${item}'"==$1){gsub($2,"'${val}'");a=0} {print $0}' ${file_path} 1<>${file_path}
}
