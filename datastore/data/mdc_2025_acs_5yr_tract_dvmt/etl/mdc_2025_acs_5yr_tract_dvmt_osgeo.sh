#!/bin/bash

# mdc_2025_acs_5yr_tract_dvmt_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://api.census.gov/data/2025/acs/acs5/
# Destination postGIS table: mdc_2025_acs_5yr_tract_dvmt
#
# Created by etl() on 2026-10-17 13:23:56
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_2025_acs_5yr_tract_dvmt/download -p /data/mdc_2025_acs_5yr_tract_dvmt/etl
chmod -R 777 /data/mdc_2025_acs_5yr_tract_dvmt
cd /data/mdc_2025_acs_5yr_tract_dvmt

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
  then wget -O download/total_population.json "https://api.census.gov/data/2025/acs/acs5?get=B01001_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_population.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_population

if [[ $do_update = 1 ]]
  then wget -O download/persons_4_years_old_and_younger.json "https://api.census.gov/data/2025/acs/acs5?get=B01001_003E%2CB01001_027E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_4_years_old_and_younger.json | awk '{ for(i=1; i<=2; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_4_years_old_and_younger

if [[ $do_update = 1 ]]
  then wget -O download/age_of_5_and_19.json "https://api.census.gov/data/2025/acs/acs5?get=B01001_004E%2CB01001_005E%2CB01001_006E%2CB01001_007E%2CB01001_028E%2CB01001_029E%2CB01001_030E%2CB01001_031E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/age_of_5_and_19.json | awk '{ for(i=1; i<=8; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln age_of_5_and_19

if [[ $do_update = 1 ]]
  then wget -O download/persons_between_the_age_of_20_and_64.json "https://api.census.gov/data/2025/acs/acs5?get=B01001_008E%2CB01001_009E%2CB01001_010E%2CB01001_011E%2CB01001_012E%2CB01001_013E%2CB01001_014E%2CB01001_015E%2CB01001_016E%2CB01001_017E%2CB01001_018E%2CB01001_019E%2CB01001_032E%2CB01001_033E%2CB01001_034E%2CB01001_035E%2CB01001_036E%2CB01001_037E%2CB01001_038E%2CB01001_039E%2CB01001_040E%2CB01001_041E%2CB01001_042E%2CB01001_043E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_between_the_age_of_20_and_64.json | awk '{ for(i=1; i<=24; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_between_the_age_of_20_and_64

if [[ $do_update = 1 ]]
  then wget -O download/persons_65_years_old_and_over.json "https://api.census.gov/data/2025/acs/acs5?get=B01001_020E%2CB01001_021E%2CB01001_022E%2CB01001_023E%2CB01001_024E%2CB01001_025E%2CB01001_044E%2CB01001_045E%2CB01001_046E%2CB01001_047E%2CB01001_048E%2CB01001_049E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/persons_65_years_old_and_over.json | awk '{ for(i=1; i<=12; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln persons_65_years_old_and_over

if [[ $do_update = 1 ]]
  then wget -O download/white_alone.json "https://api.census.gov/data/2025/acs/acs5?get=B01001A_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/white_alone.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln white_alone

if [[ $do_update = 1 ]]
  then wget -O download/black_or_african_american_alone.json "https://api.census.gov/data/2025/acs/acs5?get=B01001B_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/black_or_african_american_alone.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln black_or_african_american_alone

if [[ $do_update = 1 ]]
  then wget -O download/american_indian_and_alaska_native_alone.json "https://api.census.gov/data/2025/acs/acs5?get=B01001C_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/american_indian_and_alaska_native_alone.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln american_indian_and_alaska_native_alone

if [[ $do_update = 1 ]]
  then wget -O download/asian_alone.json "https://api.census.gov/data/2025/acs/acs5?get=B01001D_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/asian_alone.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln asian_alone

if [[ $do_update = 1 ]]
  then wget -O download/pacific_islander.json "https://api.census.gov/data/2025/acs/acs5?get=B01001E_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/pacific_islander.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln pacific_islander

if [[ $do_update = 1 ]]
  then wget -O download/some_other_race.json "https://api.census.gov/data/2025/acs/acs5?get=B01001F_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/some_other_race.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln some_other_race

if [[ $do_update = 1 ]]
  then wget -O download/two_or_more_races.json "https://api.census.gov/data/2025/acs/acs5?get=B01001G_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/two_or_more_races.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln two_or_more_races

if [[ $do_update = 1 ]]
  then wget -O download/hispanic_or_latino__any_race.json "https://api.census.gov/data/2025/acs/acs5?get=B01001I_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/hispanic_or_latino__any_race.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln hispanic_or_latino__any_race

if [[ $do_update = 1 ]]
  then wget -O download/white_alone__not_hispanic_or_latino.json "https://api.census.gov/data/2025/acs/acs5?get=B01001H_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/white_alone__not_hispanic_or_latino.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln white_alone__not_hispanic_or_latino

if [[ $do_update = 1 ]]
  then wget -O download/high_school_degree__ged_or_lower.json "https://api.census.gov/data/2025/acs/acs5?get=B15003_002E%2CB15003_003E%2CB15003_004E%2CB15003_005E%2CB15003_006E%2CB15003_007E%2CB15003_008E%2CB15003_009E%2CB15003_010E%2CB15003_011E%2CB15003_012E%2CB15003_013E%2CB15003_014E%2CB15003_015E%2CB15003_016E%2CB15003_017E%2CB15003_018E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/high_school_degree__ged_or_lower.json | awk '{ for(i=1; i<=17; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln high_school_degree__ged_or_lower

if [[ $do_update = 1 ]]
  then wget -O download/some_college__no_degree.json "https://api.census.gov/data/2025/acs/acs5?get=B15003_019E%2CB15003_020E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/some_college__no_degree.json | awk '{ for(i=1; i<=2; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln some_college__no_degree

if [[ $do_update = 1 ]]
  then wget -O download/associates_degree.json "https://api.census.gov/data/2025/acs/acs5?get=B15003_021E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/associates_degree.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln associates_degree

if [[ $do_update = 1 ]]
  then wget -O download/bachelors_degree.json "https://api.census.gov/data/2025/acs/acs5?get=B15003_022E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/bachelors_degree.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln bachelors_degree

if [[ $do_update = 1 ]]
  then wget -O download/graduate_professional_degree.json "https://api.census.gov/data/2025/acs/acs5?get=B15003_023E%2CB15003_024E%2CB15003_025E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/graduate_professional_degree.json | awk '{ for(i=1; i<=3; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln graduate_professional_degree

if [[ $do_update = 1 ]]
  then wget -O download/median_income_of_residents.json "https://api.census.gov/data/2025/acs/acs5?get=B19013_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_income_of_residents.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_income_of_residents

if [[ $do_update = 1 ]]
  then wget -O download/median_monthly_housing_costs.json "https://api.census.gov/data/2025/acs/acs5?get=B25105_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_monthly_housing_costs.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_monthly_housing_costs

if [[ $do_update = 1 ]]
  then wget -O download/median_monthly_owner_costs.json "https://api.census.gov/data/2025/acs/acs5?get=B25088_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_monthly_owner_costs.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_monthly_owner_costs

if [[ $do_update = 1 ]]
  then wget -O download/median_monthly_renter_costs.json "https://api.census.gov/data/2025/acs/acs5?get=B25058_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_monthly_renter_costs.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_monthly_renter_costs

if [[ $do_update = 1 ]]
  then wget -O download/median_monthly_owner_costs__percent_household_income.json "https://api.census.gov/data/2025/acs/acs5?get=B25092_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_monthly_owner_costs__percent_household_income.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_monthly_owner_costs__percent_household_income

if [[ $do_update = 1 ]]
  then wget -O download/median_monthly_renter_costs__percent_household_income.json "https://api.census.gov/data/2025/acs/acs5?get=B25071_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/median_monthly_renter_costs__percent_household_income.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln median_monthly_renter_costs__percent_household_income

if [[ $do_update = 1 ]]
  then wget -O download/aggregate_household_income.json "https://api.census.gov/data/2025/acs/acs5?get=B19025_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/aggregate_household_income.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln aggregate_household_income

if [[ $do_update = 1 ]]
  then wget -O download/households_below_poverty_level.json "https://api.census.gov/data/2025/acs/acs5?get=B17001_002E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/households_below_poverty_level.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln households_below_poverty_level

if [[ $do_update = 1 ]]
  then wget -O download/medicare_recipients.json "https://api.census.gov/data/2025/acs/acs5?get=C27006_004E%2CC27006_007E%2CC27006_010E%2CC27006_014E%2CC27006_017E%2CC27006_020E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/medicare_recipients.json | awk '{ for(i=1; i<=6; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln medicare_recipients

if [[ $do_update = 1 ]]
  then wget -O download/total_medicaid_recipients.json "https://api.census.gov/data/2025/acs/acs5?get=C27007_004E%2CC27007_007E%2CC27007_010E%2CC27007_014E%2CC27007_017E%2CC27007_020E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_medicaid_recipients.json | awk '{ for(i=1; i<=6; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_medicaid_recipients

if [[ $do_update = 1 ]]
  then wget -O download/total_snap_recipients.json "https://api.census.gov/data/2025/acs/acs5?get=B22002_002E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_snap_recipients.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_snap_recipients

if [[ $do_update = 1 ]]
  then wget -O download/armed_forces_veterans.json "https://api.census.gov/data/2025/acs/acs5?get=B21001_002E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/armed_forces_veterans.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln armed_forces_veterans

if [[ $do_update = 1 ]]
  then wget -O download/total_number_of_disabled_residents.json "https://api.census.gov/data/2025/acs/acs5?get=B18101_004E%2CB18101_007E%2CB18101_010E%2CB18101_013E%2CB18101_016E%2CB18101_019E%2CB18101_023E%2CB18101_026E%2CB18101_029E%2CB18101_032E%2CB18101_035E%2CB18101_038E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_number_of_disabled_residents.json | awk '{ for(i=1; i<=12; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_number_of_disabled_residents

if [[ $do_update = 1 ]]
  then wget -O download/total_housing_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25017_001E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_housing_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_housing_units

if [[ $do_update = 1 ]]
  then wget -O download/total_single_family_houses.json "https://api.census.gov/data/2025/acs/acs5?get=B25024_002E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_single_family_houses.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_single_family_houses

if [[ $do_update = 1 ]]
  then wget -O download/total_duplex_multiple_units__less_than_10_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25024_003E%2CB25024_004E%2CB25024_005E%2CB25024_006E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/total_duplex_multiple_units__less_than_10_units.json | awk '{ for(i=1; i<=4; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln total_duplex_multiple_units__less_than_10_units

if [[ $do_update = 1 ]]
  then wget -O download/number_of_housing_structures_with_10_19_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25024_007E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/number_of_housing_structures_with_10_19_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln number_of_housing_structures_with_10_19_units

if [[ $do_update = 1 ]]
  then wget -O download/number_of_housing_structures_with_20_49_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25024_008E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/number_of_housing_structures_with_20_49_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln number_of_housing_structures_with_20_49_units

if [[ $do_update = 1 ]]
  then wget -O download/number_of_housing_structures_with_50_or_more_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25024_009E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/number_of_housing_structures_with_50_or_more_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln number_of_housing_structures_with_50_or_more_units

if [[ $do_update = 1 ]]
  then wget -O download/housing_tenancy__owner_occupied_housing_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25003_002E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/housing_tenancy__owner_occupied_housing_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln housing_tenancy__owner_occupied_housing_units

if [[ $do_update = 1 ]]
  then wget -O download/housing_tenancy__renter_occupied_housing_units.json "https://api.census.gov/data/2025/acs/acs5?get=B25003_003E&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559&for=tract%3A%2A&in=state%3A12&in=county%3A086"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/housing_tenancy__renter_occupied_housing_units.json | awk '{ for(i=1; i<=1; i++) sub("\",\"", "\"|\"") } 1' |sed -e "s/\",\"//g" -e "s/\"state.*\"/\"geoid\"/1" -e "s/\"|\"/\",\"/g" | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln housing_tenancy__renter_occupied_housing_units


# Set datestamp as needed
if [[ $do_update = 1 ]]; then echo $(date '+%F %T') > datestamp; fi

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


