#!/bin/bash

# fl_2021_acs_5yr_tract_fsr_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://api.census.gov/data/2021/acs/acs5/
# Destination postGIS table: fl_2021_acs_5yr_tract_fsr
#
# Created by etl() on 2026-10-17 21:35:04
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/fl_2021_acs_5yr_tract_fsr/download -p /data/fl_2021_acs_5yr_tract_fsr/etl
chmod -R 777 /data/fl_2021_acs_5yr_tract_fsr
cd /data/fl_2021_acs_5yr_tract_fsr

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then

  # check need for update based on update frequency
  update_frequency='Never'
  no_update='-- As Needed Never'
  no_update=$(test "${no_update#*$update_frequency}" != "$no_update" && echo 1)
  if [[ ! $no_update ]]; then
    last_update=$(date -d "$(cat datestamp)" '+%s')
    check_date="$(date -d '-'"$update_frequency" '+%s')"
    if [[ "$check_date" -ge "$last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

# Download and etl as needed
if [[ $do_update = 1 ]]
  then wget -O download/total_population.json "https://api.census.gov/data/2021/acs/acs5?get=B01001_001E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_population.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_population

if [[ $do_update = 1 ]]
  then wget -O download/hispanic_population.json "https://api.census.gov/data/2021/acs/acs5?get=B01001I_001E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/hispanic_population.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln hispanic_population

if [[ $do_update = 1 ]]
  then wget -O download/creole_speaking.json "https://api.census.gov/data/2021/acs/acs5?get=C16001_008E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/creole_speaking.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln creole_speaking

if [[ $do_update = 1 ]]
  then wget -O download/latin_america_born.json "https://api.census.gov/data/2021/acs/acs5?get=B05007_048E%2CB05007_045E%2CB05007_051E%2CB05007_042E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/latin_america_born.json | awk '{ for(i=1; i<=4; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln latin_america_born

if [[ $do_update = 1 ]]
  then wget -O download/persons_4_years_old_and_younger.json "https://api.census.gov/data/2021/acs/acs5?get=B01001_003E%2CB01001_027E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_4_years_old_and_younger.json | awk '{ for(i=1; i<=2; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_4_years_old_and_younger

if [[ $do_update = 1 ]]
  then wget -O download/age_of_5_and_19.json "https://api.census.gov/data/2021/acs/acs5?get=B01001_004E%2CB01001_005E%2CB01001_006E%2CB01001_007E%2CB01001_028E%2CB01001_029E%2CB01001_030E%2CB01001_031E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/age_of_5_and_19.json | awk '{ for(i=1; i<=8; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln age_of_5_and_19

if [[ $do_update = 1 ]]
  then wget -O download/persons_between_the_age_of_20_and_64.json "https://api.census.gov/data/2021/acs/acs5?get=B01001_008E%2CB01001_009E%2CB01001_010E%2CB01001_011E%2CB01001_012E%2CB01001_013E%2CB01001_014E%2CB01001_015E%2CB01001_016E%2CB01001_017E%2CB01001_018E%2CB01001_019E%2CB01001_032E%2CB01001_033E%2CB01001_034E%2CB01001_035E%2CB01001_036E%2CB01001_037E%2CB01001_038E%2CB01001_039E%2CB01001_040E%2CB01001_041E%2CB01001_042E%2CB01001_043E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_between_the_age_of_20_and_64.json | awk '{ for(i=1; i<=24; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_between_the_age_of_20_and_64

if [[ $do_update = 1 ]]
  then wget -O download/persons_65_years_old_and_over.json "https://api.census.gov/data/2021/acs/acs5?get=B01001_020E%2CB01001_021E%2CB01001_022E%2CB01001_023E%2CB01001_024E%2CB01001_025E%2CB01001_044E%2CB01001_045E%2CB01001_046E%2CB01001_047E%2CB01001_048E%2CB01001_049E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_65_years_old_and_over.json | awk '{ for(i=1; i<=12; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_65_years_old_and_over

if [[ $do_update = 1 ]]
  then wget -O download/born_in_haiti.json "https://api.census.gov/data/2021/acs/acs5?get=B05006_138E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/born_in_haiti.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln born_in_haiti

if [[ $do_update = 1 ]]
  then wget -O download/born_in_venezuela.json "https://api.census.gov/data/2021/acs/acs5?get=B05006_164E&key=$CENSUS_API_KEY&for=tract%3A%2A&in=state%3A12"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/born_in_venezuela.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | awk '!/null/' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln born_in_venezuela


# Set datestamp as needed
if [[ $do_update = 1 ]]; then echo $(date '+%F %T') > datestamp; fi

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


