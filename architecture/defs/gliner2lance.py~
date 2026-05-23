import lancedb
import pandas as pd
import torch
import hashlib
from lancedb.pydantic import LanceModel, Vector
from lancedb.embeddings import get_registry
from gliner import GLiNER
from sentence_transformers import SentenceTransformer
from collections import defaultdict

device = "cuda:0"

model = GLiNER.from_pretrained("urchade/gliner_medium-v2.1", torch_dtype=torch.float16).to(device)

class DocVector(LanceModel):
    start: int
    end: int
    text: str
    label: str
    score: float
    id: str
    docName: str
    chunk: str
    chunkid: str
    embeddings: Vector(512)  # Add embeddings vector column


def er_functionNG(text):
    target_entities = [
        "Person",
        "Organization",
        "Location",
        "Geo-Political Entity",
        "Facility",
        "Event",
        "Law",
        "Product",
        "Work of Art",
        "Temporal Entity",
        "Numerical Value",
        "Language/Nationality",
        "Biological Entity",
        "Chemical Substance",
        "Natural Phenomenon",
        "Geographical Feature",
        "Infrastructure",
        "Technology",
        "Measurement/Indicator",
        "Land Use/Property",
        "Institution/Service",
        "Environmental Hazard",
        "Natural Resource",
        "Demographic/Social Indicator",
        "Administrative Division",
        "Hazard Zone",
        "Transportation Network",
        "Energy/Utility Infrastructure",
        "Communication Network",
        "Public Facility"
    ]

    entities = model.predict_entities(text, target_entities, threshold=0.5)
    return entities

# older function with too many target entities
def er_function(text):
    target_entities = [
        # Basic named entities
        "ORGANIZATION", "LOCATION", "GPE", "FACILITY", "EVENT", "LAW", "PRODUCT",
        "WORK_OF_ART", "PERSON", "DATE", "TIME", "MONEY", "PERCENT", "QUANTITY",
        "ORDINAL", "CARDINAL", "LANGUAGE", "NORP",

        # Natural elements
        "SUBSTANCE", "DISEASE", "CHEMICAL_SUBSTANCE", "BIOLOGICAL_ENTITY",
        "NATURAL_PHENOMENON", "GEOGRAPHICAL_FEATURE", "SPECIES", "HABITAT",
        "ECOSYSTEM", "BIODIVERSITY", "LAND_COVER", "SOIL_TYPE", "WATER_QUALITY",
        "WATER_SOURCE",

        # Built environment
        "INFRASTRUCTURE", "TRANSPORTATION", "BUILDING", "VEHICLE", "WEAPON",
        "TECHNOLOGY", "WEBSITE", "CONTACT_INFO", "IDENTIFIER", "DATASET",
        "FILE_FORMAT", "SPATIAL_REFERENCE", "COORDINATE",

        # Measurements and indicators
        "UNIT_OF_MEASUREMENT", "STATISTICAL_MEASURE", "POLLUTANT",
        "AIR_QUALITY_INDEX", "VULNERABILITY_INDEX",

        # Land use and property
        "ZONING_CODE", "LAND_USE", "PROPERTY_TYPE", "TAX_ASSESSMENT",
        "AGRICULTURAL_AREA", "INDUSTRIAL_AREA", "COMMERCIAL_AREA", "RESIDENTIAL_AREA",

        # Services and institutions
        "EDUCATIONAL_INSTITUTION", "HEALTHCARE_PROVIDER", "EMERGENCY_SERVICE",
        "PUBLIC_SERVICE", "COMMERCIAL_BUSINESS", "RECREATIONAL_AREA",

        # Environmental factors
        "ENVIRONMENTAL_HAZARD", "NATURAL_RESOURCE", "ENERGY_SOURCE",
        "CONSERVATION_AREA", "POLLUTION_SOURCE", "CONTAMINATED_SITE",
        "WASTE_MANAGEMENT_FACILITY",

        # Demographics and social indicators
        "DEMOGRAPHIC_GROUP", "INCOME_LEVEL", "POVERTY_STATUS", "EMPLOYMENT_STATUS",
        "EDUCATIONAL_ATTAINMENT", "HOUSING_TYPE", "HOUSING_TENURE", "HOUSING_COST",
        "VEHICLE_OWNERSHIP", "DISABILITY_STATUS", "HEALTH_INSURANCE_STATUS",
        "LANGUAGE_SPOKEN", "NATIVITY_STATUS", "RACE_ETHNICITY", "AGE_GROUP",
        "SEX_GENDER", "MARITAL_STATUS", "FAMILY_STRUCTURE", "VETERAN_STATUS",
        "CITIZENSHIP_STATUS", "MIGRATION_STATUS",

        # Geographic and administrative divisions
        "GEOGRAPHIC_BOUNDARY", "ADMINISTRATIVE_DIVISION", "CENSUS_GEOGRAPHY",

        # Hazard zones
        "CLIMATE_ZONE", "FLOOD_ZONE", "STORM_SURGE_ZONE", "SEISMIC_ZONE",
        "WILDFIRE_RISK_ZONE", "DROUGHT_AREA", "HEAT_ISLAND",

        # Infrastructure networks
        "TRANSPORTATION_NETWORK", "ROAD", "RAILWAY", "WATERWAY", "AIRPORT", "PORT",
        "PUBLIC_TRANSIT", "ENERGY_INFRASTRUCTURE", "POWER_PLANT", "TRANSMISSION_LINE",
        "PIPELINE", "COMMUNICATION_INFRASTRUCTURE", "BROADBAND_ACCESS", "CELL_TOWER",
        "WATER_INFRASTRUCTURE", "DAM", "RESERVOIR", "TREATMENT_PLANT", "WASTEWATER_SYSTEM",

        # Public facilities
        "HEALTHCARE_INFRASTRUCTURE", "HOSPITAL", "CLINIC", "PHARMACY",
        "EDUCATIONAL_INFRASTRUCTURE", "SCHOOL", "COLLEGE", "UNIVERSITY", "LIBRARY",
        "PUBLIC_SAFETY_INFRASTRUCTURE", "POLICE_STATION", "FIRE_STATION",
        "EMERGENCY_SHELTER", "GOVERNMENT_BUILDING", "COMMUNITY_CENTER",
        "RELIGIOUS_BUILDING", "CULTURAL_VENUE", "SPORTS_FACILITY", "PARK",
        "GREEN_SPACE", "HISTORICAL_SITE", "TOURIST_ATTRACTION"
    ]

    entities = model.predict_entities(text, target_entities, threshold=0.5)
    return entities


def processor(db_path: str = None, source_table: str = None, output_table: str = None,):
    # Initialize embedding model
    embedding_model = SentenceTransformer("jinaai/jina-embeddings-v2-small-en", device="cpu")
    
    # set up elements
    db = lancedb.connect(db_path)
    table = db.open_table(source_table)

    df = table.to_pandas()
    df_b = pd.DataFrame()

    for index, row in df.iterrows():
        # result_dict = er_function(row["description"])
        result_dict = er_functionNG(row["description"])
        if result_dict:
            df_er = pd.DataFrame(result_dict)
            df_er["id"] = row["id"]
            df_er["docName"] = row["filename"]
            df_er["chunk"] = row["description"]
            df_er["chunkid"] = hashlib.md5(row["description"].encode()).hexdigest()
            df_b = pd.concat([df_b, df_er], ignore_index=True)

    # Generate embeddings for the extracted text entities
    print("Generating embeddings for extracted entities...")
    entity_texts = df_b['chunk'].tolist()  ## TODO:  was on 'text', but this a bad column to do this on, try "chunk"?   or other?
    embeddings = embedding_model.encode(entity_texts, show_progress_bar=True).tolist()
    df_b['embeddings'] = embeddings

    # df_b.to_csv('original_dataframe.csv', index=False)

    db = lancedb.connect(db_path)
    if output_table in db.table_names():
        db.drop_table(output_table)
    
    # Create table with embeddings support
    table = db.create_table(output_table, schema=DocVector.to_arrow_schema())
    table.add(data=df_b)
    
    # Create full text index on relevant text columns
    print("Creating full text search index...")
    table.create_fts_index(["text", "chunk"], replace=True, use_tantivy=True)
    
    print(f"Table '{output_table}' created with embeddings and full text index.")
